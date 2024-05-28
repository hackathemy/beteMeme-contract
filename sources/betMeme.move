module betmeme::betmeme {
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    public struct Game<phantom T> has key, store {
        id: UID,
        startTime: u64,
        duration: u64,
        markedPrice: u64,
        lastPrice: u64,
        upBalance: Balance<T>,
        downBalance: Balance<T>,
        prizeBalance: Balance<T>,
    }

    public struct UserBet has key, store {
        id: UID,
        gameId: ID,
        betUp: bool,
        amount: u64,
    }

    public entry fun create<T>(markedPrice: u64, duration: u64, clock: &Clock, coin: Coin<T>, ctx: &mut TxContext) {
        let game = Game {
            id: object::new(ctx),
            startTime: clock.timestamp_ms(),
            duration: duration,
            markedPrice: markedPrice,
            lastPrice: 0,
            upBalance: balance::zero(),
            downBalance: balance::zero(),
            prizeBalance: coin::into_balance(coin),
        };
        transfer::share_object(game);
    }

    public entry fun bet<T>(game: &mut Game<T>, clock: &Clock, betUp: bool, coin: Coin<T>, ctx: &mut TxContext) {
        assert!(game.startTime + game.duration > clock.timestamp_ms(), 403);

        let amount = balance::value(coin.balance());
        if (betUp) {
            game.upBalance.join(coin.into_balance());
        } else {
            game.downBalance.join(coin.into_balance());
        };

        let userBet = UserBet {
            id: object::new(ctx),
            gameId: object::uid_to_inner(&game.id),
            betUp: betUp,
            amount: amount,
        };
        let sender = tx_context::sender(ctx);
        transfer::public_transfer(userBet, sender);
    }

    public entry fun gameEnd<T>(game: &mut Game<T>, clock: &Clock, lastPrice: u64, ctx: &mut TxContext) {
        assert!(game.startTime + game.duration > clock.timestamp_ms(), 403);
        game.lastPrice = lastPrice;
        if (game.lastPrice > game.markedPrice) {
            let amount = balance::value(&game.downBalance);
            let winnerPrize = balance::split(&mut game.downBalance, amount / 30);
            game.upBalance.join(winnerPrize);
            let burnCoin = game.downBalance.split(amount / 50).into_coin(ctx);
            transfer::public_transfer(burnCoin, @burn_address);
        } else {
            let amount = balance::value(&game.upBalance);
            let winnerPrize = balance::split(&mut game.upBalance, amount / 30);
            game.downBalance.join(winnerPrize);
            let burnCoin = game.upBalance.split(amount / 50).into_coin(ctx);
            transfer::public_transfer(burnCoin, @burn_address);
        }
    }

    public entry fun claim<T>(game: &mut Game<T>, userBet: UserBet, ctx: &mut TxContext) {
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