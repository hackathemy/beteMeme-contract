module my_first_package::beteMeme {
    use sui::clock::{Clock};
    use sui::event;
    use sui::coin::{Self, Coin};
    use sui::balance::{Self, Balance};

    public struct GameOwnerCap has key { id: UID }

    public struct FUD has drop {}

    public struct Game has key {
        id: UID,
        startTime: u64,
        // coinObjectId: address, //
        end: bool, // true end, false ing
        winner: bool, // true up, false down
    }

    public struct FeeAdd has key {
        id: UID,
        balance: Balance<FUD>,
    }

    public struct UpBalance has key{
        id: UID,
        balance: Balance<FUD>,
    }

    public struct DownBalance has key {
        id: UID,
        balance: Balance<FUD>,
    }

    public struct UserInfo has key { // ??????????
        id: UID,
        betUp: bool, // 승리에 배팅 up, 패배에 배팅 down
        betAmount: u64,
    }

    public struct BetEvent has copy, drop {
        id: ID,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(GameOwnerCap {
            id: object::new(ctx)
        }, ctx.sender());
    }

    // onlyOwner
    public fun createGame(_: &GameOwnerCap, clock: &Clock ,ctx: &mut TxContext) : Game{
        Game {
            id: object::new(ctx),
            startTime: clock.timestamp_ms(),
            // coinObjectId: address, //
            end: false,
            winner: false,
        }
    }

    public entry fun betUp(wallet: &mut Coin<FUD>, up: &mut UpBalance, fee: &mut FeeAdd, game: &Game, amount: u64, ctx: &mut TxContext) {
        assert!(game.end == true, 403); // "game is end"
        let coins_to_trade = balance::split(coin::balance_mut(wallet), amount);
        // 1% fee.
        let fees = balance::split(&mut coins_to_trade, amount / 100);

        balance::join(&mut up.balance, coins_to_trade);
        balance::join(&mut fee.balance, fees);

        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);

        transfer::transfer(UserInfo {
            id: uid,
            betUp:  true,
            betAmount: amount,
        }, ctx.sender());

        event::emit(BetEvent {
            id
        });
    }

    public entry fun betDown(wallet: &mut Coin<FUD>, down: &mut DownBalance, fee: &mut FeeAdd, game: &Game, amount: u64, ctx: &mut TxContext) {
        assert!(game.end == true, 403); // "game is end"
        let coins_to_trade = balance::split(coin::balance_mut(wallet), amount);
        // 1% fee. 바로 특정 주소로 보내도 됨
        let fees = balance::split(&mut coins_to_trade, amount / 100);

        balance::join(&mut down.balance, coins_to_trade);
        balance::join(&mut fee.balance, fees);

        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);

        transfer::transfer(UserInfo {
            id: uid,
            betUp:  true,
            betAmount: amount,
        }, ctx.sender());

        event::emit(BetEvent {
            id
        });
    }

    // onlyOwner
    public fun endGameWinnerUp(_: &GameOwnerCap, down: &mut DownBalance, game: &mut Game) {
        assert!(game.end == false, 403); // "already end"
        game.end = true;
        game.winner = true; // up 승리
     
        let _burnAmount = balance::split(&mut down.balance, (balance::value(&down.balance) / 10) * 8);
        // 이러면 burnAmount 만큼의 수량은 따로 저장 안해서 날라갈듯?
    }

    // onlyOwner
    public fun endGameWinnerDown(_: &GameOwnerCap, up: &mut UpBalance, game: &mut Game) {
        assert!(game.end == false, 403); // "already end"
        game.end = true;
        game.winner = false; // down 승리
       
        let _burnAmount = balance::split(&mut up.balance, (balance::value(&up.balance) / 10) * 8);
        // 이러면 burnAmount 만큼의 수량은 따로 저장 안해서 날라갈듯?
    }

    public entry fun claim(game: &Game, up: &mut UpBalance, down: &mut DownBalance, userInfo: UserInfo, ctx: &mut TxContext) {
        assert!(game.end == true, 403); // "playing"

        let amount = userInfo.betAmount;
        let withdrawal: Balance<FUD>;

        if(userInfo.betUp){
            withdrawal = balance::split(&mut up.balance, amount);
        } else {
            withdrawal = balance::split(&mut down.balance, amount);
        };

        // 배팅한 금액 전부 주면 진팀은 20%만 인출 가능
        // 유저인포 오브젝트 삭제
        let UserInfo {
            id,
            betUp: _, // 승리에 배팅 up, 패배에 배팅 down
            betAmount: _,
        } = userInfo;

        object::delete(id);

        let coin = coin::from_balance(withdrawal, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }

    // onlyOwner
    public fun feeClaim(_: &GameOwnerCap, fees: &mut FeeAdd, ctx: &mut TxContext) {
        let fee = balance::split(&mut fees.balance, balance::value(&fees.balance));
        let coin = coin::from_balance(fee, ctx);
        transfer::public_transfer(coin, tx_context::sender(ctx));
    }
}