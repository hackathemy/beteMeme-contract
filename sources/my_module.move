module my_first_package::my_module {
    use sui::clock::{Self, Clock};
    use std::option::{Self, Option};
    use sui::coin::{Coin};

    public struct GameOwnerCap has key { id: UID }

    public struct Game has key, store {
        id: UID,
        startTime: u64,
        // upBalance: u256, // Option<ID>, // u256?
        // downBalance: u256, // Option<ID>, // u256?
        balances: vector<u256>,
        coinObjectId: bool, //
        end: bool,
        burnVector: u8, // 0 up, 1 down
    }

    public struct UserInfo has key, store { // ??????????
        id: UID,
        betUp: bool, // 승리에 배팅 up, 패배에 배팅 down
        betAmount: u256,
    }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(GameOwnerCap {
            id: object::new(ctx)
        }, ctx.sender());
    }

    // onlyOwner
    fun createGame(_: &GameOwnerCap, clock: &Clock ,ctx: &mut TxContext) : Game{
        Game {
            id: object::new(ctx),
            startTime: clock.timestamp_ms(),
            // upBalance: 0, // option::none()
            // downBalance: 0,
            balances: vector[0,0],
            coinObjectId: false, //
            end: false,
            burnVector: 0,
        }
    }



    public fun userBetUp(bet: bool, game: &Game, ctx: &mut TxContext) {
        assert!(game.end == false, 403); // "game is end"
        // 유저 퍼드 이동, 기록?
        // 유저가 주는 파라미터 처리하는게 없나??????????????

        // Take amount = `shop.price` from Coin<SUI> 퍼드
        // let paid = payment.balance_mut().split(shop.price);

        // 유저가 보낸 토큰에서 수수료 1% 먹고 99%로를 기준삼음.
        // 배팅 확인해서 ++ 

        transfer::transfer(UserInfo {
            id: object::new(ctx),
            betUp: bet, // ?
            betAmount: 0, //
        }, ctx.sender())
    }

    // onlyOwner
    public fun endGame(_: &GameOwnerCap, burnVector: u8, game: &mut Game) { // onlyOwner
        game.end = true;
        game.burnVector = burnVector; // 0 - up, 1 -down

        // let burnAmount: u256;
        // if(result) {
        //     burnVector
        //     game.downBalance = burnAmount
        // } else {
        //     burnAmount = (game.downBalance / 10) * 8;
        //     game.upBalance = burnAmount
        // } // 맵핑 있으면 - result 0 or 1 로 바꿔서 if 없이 

        

        // game.balances[burnVector] = (game.balances[burnVector] / 10) * 8;
        let balance = vector::borrow_mut(&mut game.balances, burnVector as u64);

        // balance = (balance / 10) * 8
        // burn  burnAmount
    
    }

    public fun claim(game: &Game, userInfo: &mut UserInfo) {
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
    }
}