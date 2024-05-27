module betmeme::betmeme {
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};
    use std::type_name::{TypeName};

    public struct BetMeme has key {
        id: UID,
        owner: address,
        inventory: vector<Game>
    }

    public struct Game has key, store {
        id: UID,
        startTime: u64,
        duration: u64,
        markedPrice: u64,
        lastPrice: u64,
        upBalance: Balance<TypeName>,
        upAmount: u64,
        downBalance: Balance<TypeName>,
        downAmount: u64,
    }

    public struct UserBet has key, store {
        id: UID,
        betUp: bool,
        amount: u64,
    }

    public fun owner(betmeme: &BetMeme): address {
        betmeme.owner
    }

    public entry fun create(ctx: &mut TxContext) {
        transfer::share_object(BetMeme {
            id: object::new(ctx),
            owner: tx_context::sender(ctx),
            inventory: vector::empty<Game>()
        })
    }

    public entry fun createGame(betmeme: &mut BetMeme, markedPrice: u64, duration: u64, clock: &Clock, ctx: &mut TxContext) {
        let item = Game {
            id: object::new(ctx),
            startTime: clock.timestamp_ms(),
            duration: duration,
            markedPrice: markedPrice,
            lastPrice: 0,
            upBalance: balance::zero(),
            upAmount: 0,
            downBalance: balance::zero(),
            downAmount: 0,
        };
        vector::push_back(&mut betmeme.inventory, item);
    }

    public entry fun bet(game: &mut Game, clock: &Clock, betUp: bool, amount: u64, coin: &mut Coin<TypeName>, ctx: &mut TxContext) {
        assert!(game.startTime + game.duration < clock.timestamp_ms(), 403);

        let paid = coin.balance_mut().split(amount);
        if (betUp) {
            game.upBalance.join(paid);
            game.upAmount = game.upAmount + amount;
        } else {
            game.downBalance.join(paid);
            game.downAmount = game.downAmount + amount;
        };

        let userBet = UserBet {
            id: object::new(ctx),
            betUp: betUp,
            amount: amount,
        };
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(userBet, sender);
    }

    public entry fun gameEnd(game: &mut Game, clock: &Clock, lastPrice: u64, ctx: &mut TxContext) {
        assert!(game.startTime + game.duration > clock.timestamp_ms(), 403);
        game.lastPrice = lastPrice;
        if (game.lastPrice > game.markedPrice) {
            let winnerPrize = balance::split(&mut game.downBalance, game.downAmount / 30);
            game.upBalance.join(winnerPrize);
            let burnCoin = game.downBalance.split(game.downAmount / 50).into_coin(ctx);
            transfer::public_transfer(burnCoin, @burn_address);
        } else {
            let winnerPrize = balance::split(&mut game.upBalance, game.upAmount / 30);
            game.downBalance.join(winnerPrize);
            let burnCoin = game.upBalance.split(game.upAmount / 50).into_coin(ctx);
            transfer::public_transfer(burnCoin, @burn_address);
        }
    }

    public entry fun claim(game: &mut Game, userBet: UserBet, ctx: &mut TxContext) {
        let amount = userBet.amount;

        if(userBet.betUp){
            let _upBalance = balance::value(&game.upBalance);
            assert!(0 <= _upBalance, 403);
            let withdraw = balance::split(&mut game.upBalance, amount);
            let coin = coin::from_balance(withdraw, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx));
        } else {
            let _downBalance = balance::value(&game.downBalance);
            assert!(0 <= _downBalance, 403);
            let withdraw = balance::split(&mut game.downBalance, amount);
            let coin = coin::from_balance(withdraw, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx));
        };

        transfer::public_transfer(userBet, @burn_address);
    }
}