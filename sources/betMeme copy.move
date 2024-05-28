module my_first_package::beteMeme {
    use sui::clock::{Clock};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use std::type_name::{TypeName};

    public struct GameOwnerCap has key { id: UID }

    public struct BetMemeGames has key {
        id: UID,
        owner: address,
        inventory: vector<Game>,
    }

    public struct Game has key, store {
        id: UID,
        startTime: u64,
        duration: u64,
        markedPrice: u64,
        lastPrice: u64,
        burnAmount: u64,
        upBalance: Balance<TypeName>,
        upAmount: u64,
        downBalance: Balance<TypeName>,
        downAmount: u64,
        challenge: Balance<TypeName>,
    }

    public struct UserBet has key {
        id: UID,
        betUp: bool, // 승리에 배팅 true, 패배에 배팅 false
        amount: u64,
        callenge: bool,
    }

    public struct BetEvent has copy, drop {
        id: ID,
        betUp: bool, // 승리에 배팅 true, 패배에 배팅 false
        betAmount: u64,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(GameOwnerCap {
            id: object::new(ctx)
        }, ctx.sender());

        transfer::share_object(BetMemeGames {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            inventory: vector::empty<Game>()
        });
    }

    // onlyOwner
    public entry fun createGame(_: &GameOwnerCap, betmeme: &mut BetMemeGames, markedPrice: u64, duration: u64, clock: &Clock, ctx: &mut TxContext) {
        let item = Game {
            id: object::new(ctx),
            startTime: clock.timestamp_ms(),
            duration: duration,
            markedPrice: markedPrice,
            lastPrice: 0,
            burnAmount: 0,
            upBalance: balance::zero(),
            upAmount: 0,
            downBalance: balance::zero(),
            downAmount: 0,
            challenge: balance::zero(),
        };
        vector::push_back(&mut betmeme.inventory, item);
    }

    public entry fun betUp(sys: &BetMemeGames, game: &mut Game, clock: &Clock, betUp: bool, amount: u64, coin: &mut Coin<TypeName>, ctx: &mut TxContext) {
        assert!(clock.timestamp_ms() > game.startTime + game.duration, 403); // 배팅 제한 시간

        let paid = coin.balance_mut().split(amount);
        let fee = coin.balance_mut().split(amount / 100);
        let coin = coin::from_balance(fee, ctx);
        transfer::public_transfer(coin, sys.owner);

        if (betUp) {
            game.upBalance.join(paid);
            game.upAmount = game.upAmount + amount;
        } else {
            game.downBalance.join(paid);
            game.downAmount = game.downAmount + amount;
        };

        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);

        transfer::transfer(UserBet {
            id: uid,
            betUp,
            amount,
            callenge: false,
        }, ctx.sender());

        event::emit(BetEvent {
            id,
            betUp,
            betAmount: amount,
        });
    }

    public entry fun gameEnd(_: &GameOwnerCap, game: &mut Game, clock: &Clock, lastPrice: u64, ctx: &mut TxContext) {
        assert!(game.startTime + game.duration > clock.timestamp_ms(), 403);
        game.lastPrice = lastPrice;

        let burnCoin: Coin<TypeName>;
        if (game.lastPrice > game.markedPrice) {
            let winnerPrize = balance::split(&mut game.downBalance, (game.downAmount / 10) * 8);
            game.challenge.join(winnerPrize);
            burnCoin = game.downBalance.split(game.downAmount / 2).into_coin(ctx);
            transfer::public_transfer(burnCoin, @0x0);
        } else {
            let winnerPrize = balance::split(&mut game.upBalance, (game.upAmount / 10) * 8);
            game.challenge.join(winnerPrize);
            burnCoin = game.upBalance.split(game.upAmount / 2).into_coin(ctx);
            transfer::public_transfer(burnCoin, @0x0);
        };
    }

    public entry fun claim(game: &mut Game, userBet: UserBet, ctx: &mut TxContext) {
        assert!(game.lastPrice != 0, 403); // 종료가격 셋팅 이후 클레임 가능
        let amount = userBet.amount;

        let withdraw:Balance<TypeName>;
        if(userBet.betUp){
            let _upBalance = balance::value(&game.upBalance);
            assert!(0 <= _upBalance, 403);
            if(_upBalance < amount){
                withdraw = balance::split(&mut game.upBalance, amount);
            }else {
                withdraw = balance::split(&mut game.upBalance, amount);
            };
        } else {
            let _downBalance = balance::value(&game.downBalance);
            assert!(0 <= _downBalance, 403);
            if(_downBalance < amount){
                withdraw = balance::split(&mut game.downBalance, amount);
            } else {
                withdraw = balance::split(&mut game.downBalance, amount);
            };
        };

        let coin = coin::from_balance(withdraw, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));

        let UserBet {
            id,
            betUp: _,
            amount: _,
            callenge: _,
        } = userBet;

        object::delete(id);
    }

    // 이긴사람만 가능 현재 첼린지 풀에서 10% 획득
    public entry fun callenge(game: &mut Game, userBet: &mut UserBet, ctx: &mut TxContext) {
        assert!(game.lastPrice != 0, 403); // 종료가격 셋팅 이후 클레임 가능
        assert!(userBet.callenge == false, 403);
        
        let winner:bool;
        if(game.lastPrice > game.markedPrice){
            winner = true;
        } else {
            winner = false;
        };
        assert!(userBet.betUp == winner, 403);

        userBet.callenge = true;

        let _getBalance = balance::value(&game.challenge);
        let withdraw = balance::split(&mut game.challenge, _getBalance / 10);

        let coin = coin::from_balance(withdraw, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }
}