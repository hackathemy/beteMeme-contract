module my_first_package::my_module1 {
    use sui::clock::{Self, Clock};
    use std::option::{Self};
    use sui::event;
    use sui::coin::{Coin};

    public struct GameOwnerCap has key { id: UID }

    public struct Game has key {
        id: UID,
        startTime: u64,
        coinObjectId: bool, //
        end: bool, // true end, false ing
        winner: bool, // true up, false down
    }

    public struct TotalBet has key {
        id: UID,
        upBalance: u256,
        downBalance: u256,
    }

    public struct UserInfo has key { // ??????????
        id: UID,
        betUp: bool, // 승리에 배팅 up, 패배에 배팅 down
        betAmount: u256,
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
            coinObjectId: false, //
            end: false,
            winner: false,
        }
    }



    public fun bet(betUp: bool, game: &Game, total: &mut TotalBet, ctx: &mut TxContext) {
        assert!(game.end == true, 403); // "game is end"
        // 유저 퍼드 이동, 기록?
        // 유저가 주는 파라미터 처리하는게 없나??????????????

        // Take amount = `shop.price` from Coin<SUI> 퍼드
        // let paid = payment.balance_mut().split(shop.price);

        // 유저가 보낸 토큰에서 수수료 1% 먹고 99%로를 기준삼음.
        // 배팅 확인해서 ++

        if(betUp){
            total.upBalance = 0; //
        } else {
            total.downBalance = 0; //
        };

        let uid = object::new(ctx);
        let id = object::uid_to_inner(&uid);

        transfer::transfer(UserInfo {
            id: uid,
            betUp,
            betAmount: 0, //
        }, ctx.sender());

        event::emit(BetEvent {
            id
        });
    }

    // onlyOwner
    public fun endGame(_: &GameOwnerCap, winner: bool, total: &mut TotalBet, game: &mut Game) {
        assert!(game.end == false, 403); // "already end"
        game.end = true;
        game.winner = winner;
       
        let burnAmount: u256;
        if(winner) {
            burnAmount = (total.downBalance / 10) * 8;
            total.downBalance = burnAmount
        } else {
            burnAmount = (total.upBalance / 10) * 8;
            total.upBalance = burnAmount
        } // 맵핑 있으면 - result 0 or 1 로 바꿔서 if 없이 

        // burn  burnAmount    
    }

    public fun claim(game: &Game, userInfo: UserInfo) {
        assert!(game.end == true, 403); // "playing"

            /// Take coin from `DonutShop` and transfer it to tx sender.
            /// Requires authorization with `ShopOwnerCap`.
            // public fun collect_profits(
            //     _: &ShopOwnerCap, shop: &mut DonutShop, ctx: &mut TxContext
            // ): Coin<SUI> {
            //     let amount = shop.balance.value();
            //     shop.balance.split(amount).into_coin(ctx)
            // }

        // 배팅한 금액 전부 주면 진팀은 20%만 인출 가능

        // 유저인포 오브젝트 삭제

        let UserInfo {
            id,
            betUp: _, // 승리에 배팅 up, 패배에 배팅 down
            betAmount: _,
        } = userInfo;

        object::delete(id);
    }
}