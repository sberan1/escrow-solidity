## Escrow Manager
This contract written in Solidity is designed to help with Escrow contracts. It is made for people that need a middleman to execute their transaction safely.

### Workflow
1. **Setup:** The **Seller** creates an escrow contract with the addresses of the **Buyer** and **Arbiter** (agreed upon by both sides). The Seller also specifies the amount to be deposited.
2. **Deposit:** The **Buyer** deposits the specified amount into the contract.
3. **Delivery:** After the deposit is made, the **Seller** ships the product.
4. **Completion:** The **Buyer** confirms delivery. If everything goes well, this triggers the payment to the Seller and the Escrow is finished.

#### Cancelation
**Seller** can cancel the escrow if the **Buyer** fails to deposits the funds in timely manner. 


### Dispute Resolution
If either side fails to hold up the deal (e.g., Seller ships wrong item, delivery never happens, or Buyer fails to confirm), the **Arbiter** decides the dispute.

*   The Arbiter can split the amount between both sides.
*   *Example:* If the Buyer finds a scratch on the product that wasn't disclosed, the Arbiter can refund just a part of the money.
*   The sides decide on Arbiter payment outside of the blockchain.
*   If the arbiter loses access to the account it's up to the **Buyer** to somehow get the money from him, otherwise they stay in the contract forever lost, every other solution would only create security issue for one side or the other.

The funds are held inside the contract until the dispute is resolved.

## Usage

### Build

```shell
$ forge build
```

### Test

```shell
$ forge test
```

### Format

```shell
$ forge fmt
```

### Gas Snapshots

```shell
$ forge snapshot
```

### Anvil

```shell
$ anvil
```

### Deploy

```shell
$ forge script script/Escrows.sol:Escrows --rpc-url <your_rpc_url> --private-key <your_private_key>
```

### Cast

```shell
$ cast <subcommand>
```

### Help

```shell
$ forge --help
$ anvil --help
$ cast --help
```
