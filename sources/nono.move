/// Unlike `Owned` objects, `Shared` ones can be accessed by anyone on the
/// network. Extended functionality and accessibility of this kind of objects
/// requires additional effort by securing access if needed.
module examples::donuts {
    use sui::sui::SUI;
    use sui::coin::Coin;
    use sui::balance::{Self, Balance};

    /// For when Coin balance is too low.
    const ENotEnough: u64 = 0;

    /// Capability that grants an owner the right to collect profits.
    public struct ShopOwnerCap has key { id: UID }

    /// A purchasable Donut. For simplicity's sake we ignore implementation.
    public struct Donut has key { id: UID }

    /// A shared object. `key` ability is required.
    public struct DonutShop has key {
        id: UID,
        price: u64,
        balance: Balance<SUI>
    }

    /// Init function is often ideal place for initializing
    /// a shared object as it is called only once.
    ///
    /// To share an object `transfer::share_object` is used.
    fun init(ctx: &mut TxContext) {
        transfer::transfer(ShopOwnerCap {
            id: object::new(ctx)
        }, ctx.sender());

        // Share the object to make it accessible to everyone!
        transfer::share_object(DonutShop {
            id: object::new(ctx),
            price: 1000,
            balance: balance::zero()
        })
    }

    /// Entry function available to everyone who owns a Coin.
    public fun buy_donut(
        shop: &mut DonutShop, payment: &mut Coin<SUI>, ctx: &mut TxContext
    ) {
        assert!(payment.value() >= shop.price, ENotEnough);

        // Take amount = `shop.price` from Coin<SUI>
        let paid = payment.balance_mut().split(shop.price);

        // Put the coin to the Shop's balance
        shop.balance.join(paid);

        transfer::transfer(Donut {
            id: object::new(ctx)
        }, ctx.sender())
    }

    /// Consume donut and get nothing...
    public fun eat_donut(d: Donut) {
        let Donut { id } = d;
        id.delete();
    }

    /// Take coin from `DonutShop` and transfer it to tx sender.
    /// Requires authorization with `ShopOwnerCap`.
    public fun collect_profits(
        _: &ShopOwnerCap, shop: &mut DonutShop, ctx: &mut TxContext
    ): Coin<SUI> {
        let amount = shop.balance.value();
        shop.balance.split(amount).into_coin(ctx)
    }
}
