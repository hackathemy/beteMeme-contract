module betmeme::betmeme {
    use sui::clock::{Clock};
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    public struct Game<phantom T> has key, store {
        id: UID,
        startTime: u64,
        duration: u64, // 밀리초
        markedPrice: u64,
        lastPrice: u64,
        minAmount: u64, // 최소 배팅 수량
        upAmount: u64,
        downAmount: u64,
        prizeAmount: u64,
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

    public entry fun create<T>(markedPrice: u64, duration: u64, minAmount: u64, clock: &Clock, coin: Coin<T>, ctx: &mut TxContext) {
        let game = Game {
            id: object::new(ctx),
            startTime: clock.timestamp_ms(),
            duration, // 밀리초
            markedPrice,
            lastPrice: 0,
            minAmount,
            upAmount: 0,
            downAmount: 0,
            prizeAmount: 0,
            upBalance: balance::zero(),
            downBalance: balance::zero(),
            prizeBalance: coin::into_balance(coin),
        };
        transfer::share_object(game);
    }

    public entry fun bet<T>(game: &mut Game<T>, clock: &Clock, betUp: bool, coin: Coin<T>, ctx: &mut TxContext) {
        assert!(game.startTime + game.duration > clock.timestamp_ms(), 403);
        let amount = balance::value(coin.balance());
        assert!(amount > game.minAmount); // 최소 입금 수량보다 많이

        if (betUp) {
            game.upBalance.join(coin.into_balance());
            game.upAmount = game.upAmount + amount;
        } else {
            game.downBalance.join(coin.into_balance());
            game.downAmount = game.downAmount + amount;
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
            // let winnerPrize = balance::split(&mut game.downBalance, amount / 2); //50퍼
            // game.upBalance.join(winnerPrize);
            let burnCoin = game.downBalance.split(amount / 5).into_coin(ctx); // 20퍼
            // 남은 30퍼 상금풀로
            let challenge = balance::value(&game.downBalance);
            let prize = balance::split(&mut game.downBalance, challenge);
            game.prizeBalance.join(prize);
            game.downAmount = game.downAmount / 2;
            transfer::public_transfer(burnCoin, @burn_address);
        } else {
            let amount = balance::value(&game.upBalance);
            // let winnerPrize = balance::split(&mut game.upBalance, amount / 2);
            // game.downBalance.join(winnerPrize);
            let burnCoin = game.upBalance.split(amount / 5).into_coin(ctx);
            // 남은 30퍼 상금풀로
            let challenge = balance::value(&game.upBalance);
            let prize = balance::split(&mut game.upBalance, challenge);
            game.prizeBalance.join(prize);
            game.upAmount = game.upAmount / 2;
            transfer::public_transfer(burnCoin, @burn_address);
        }
    }

    // 이긴사람만 클레임 가능
    public entry fun claim<T>(game: &mut Game<T>, userBet: &mut UserBet, clock: &Clock, ctx: &mut TxContext) {
        // 배팅 종료 후 하루 뒤
        assert!(game.startTime + game.duration  + 86400000 < clock.timestamp_ms(), 403);
        // lastprice가 없으면 안되도록 수정 
        assert!(game.lastPrice != 0, 403);
        assert!(userBet.amount != 0, 403);
        let win: bool;
        if(game.lastPrice > game.markedPrice){
            win = true;
        } else { 
            win = false;
        };
        assert!(win == userBet.betUp, 403);
        // 조건 맞는지 확인 필요
        let amount = userBet.amount;
        userBet.amount = 0;

        // 50퍼 먹은걸 잘 분배해야됨 
        if(userBet.betUp){
            let _upBalance = balance::value(&game.upBalance);
            assert!(0 <= _upBalance, 403);
            let withdraw = balance::split(&mut game.upBalance, amount);

            let rate = game.upAmount / amount;
            let reward = game.downAmount / 100 * rate;
            let get = balance::split(&mut game.downBalance, reward);

            let coin = coin::from_balance(withdraw, ctx);
            let coin1 = coin::from_balance(get, ctx);

            transfer::public_transfer(coin, tx_context::sender(ctx));
            transfer::public_transfer(coin1, tx_context::sender(ctx));
        } else {
            let _downBalance = balance::value(&game.downBalance);
            assert!(0 <= _downBalance, 403);
            let withdraw = balance::split(&mut game.downBalance, amount);

            let rate = game.downAmount / amount;
            let reward = game.upAmount / 100 * rate;
            let get = balance::split(&mut game.upBalance, reward);

            let coin = coin::from_balance(withdraw, ctx);
            let coin1 = coin::from_balance(get, ctx);

            transfer::public_transfer(coin, tx_context::sender(ctx));
            transfer::public_transfer(coin1, tx_context::sender(ctx));
        };
               
        // 어마운트 0으로 바꾸고 코인도 없어서 괜찮
        // transfer::public_transfer(userBet, @burn_address);
    }

    // 진팀 물량의 30퍼 먹기 선착순(업 다운 모두 참여가능)
    // 이거 하면 claim 못하니까 안내 잘 해줘야함
    public entry fun callenge<T>(game: &mut Game<T>, userBet: UserBet, ctx: &mut TxContext) {
        // 종료가격 셋팅 이후 callenge 가능
        assert!(game.lastPrice != 0, 403); 

        let _getBalance = balance::value(&game.prizeBalance);
        assert!(_getBalance != 0); 
        if(_getBalance > game.minAmount / 100){
            let withdraw = balance::split(&mut game.prizeBalance, _getBalance / 10);

            let coin = coin::from_balance(withdraw, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx));
        }else {
            // 최소보다 작게 남았으면 그사람은 나머지 다 가져감
            // 선착순 물량보다 크더라도 상관없음(로또)
            let withdraw = balance::split(&mut game.prizeBalance, _getBalance); 

            let coin = coin::from_balance(withdraw, ctx);
            transfer::public_transfer(coin, tx_context::sender(ctx));
        };
        transfer::public_transfer(userBet, @burn_address);
    }
}
