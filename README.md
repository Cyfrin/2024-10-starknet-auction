# Contest Details

### Prize Pool

- High - 100xp
- Medium - 20xp
- Low - 2xp

- Starts: October 10, 2024 Noon UTC
- Ends: October 17, 2024 Noon UTC

### Stats

- nSLOC: 132

# Starknet Auction

## Disclaimer

_This code was created for Codehawks as the first flight. It is made with bugs and flaws on purpose._
_Don't use any part of this code without reviewing it and audit it._

_Created by Bube_

[//]: # (contest-details-open)

# About

The Starknet Auction protocol is a simple auction protocol that enables the auction of NFTs using ERC20 tokens as bid currency. The NFT owner is the admin of the protocol. The NFT owner deploys the protocol and starts the auction. The participants in the auction (called users/bidders) place bids. Each bid should be bigger than the previous highest bid. The participants may have multiple bids. Аfter the auction time expires the bidder who made the highest bid wins the auction and receives the NFT. The owner of the NFT receives the value of the highest bid and the other participants can withdraw their unsuccessful bids.

## Functions:

- `start` - This function starts the auction, setting the bidding duration, the starting price, and marking the auction as started. It also transfers the NFT from the owner to the auction contract. Only the owner of the contract can call this function.

- `bid` - Users/Bidders can place bids with `ERC20` tokens. The bid must be higher than the current highest bid. The contract updates the highest bid and highest bidder upon receiving a valid bid. The `ERC20` tokens for the bid are transferred to the contract.

- `withdraw` - The owner withdraws the value of the highest bid, and other participants withdraw their unsuccessful bids after the end of the auction.

- `end` - This function finalizes the auction. It checks that the auction duration has elapsed and transfers the NFT to the highest bidder and marks the auction as ended. Only the owner of the contract can call this function.

- `get_bid` - This is a getter function that returns the current highest bid in the auction.

## Actors

- NFT Owner/Admin (Trusted) - Initiates the auction and receives the value of the highest bid. 
- Bidders/Users - Place bids and can withdraw their bids if they don't win. The bidder with the highest bid wins the NFT.

[//]: # (contest-details-close)

[//]: # (getting-started-open)

# Getting Started

## Requirements

You should install [`Scarb`](https://docs.swmansion.com/scarb/download.html). 
It is recommended to install Scarb via [`asdf`](https://docs.swmansion.com/scarb/download.html#install-via-asdf), a CLI tool that can manage multiple language runtime versions on a per-project basis. This will ensure that the version of Scarb you use to work on a project always matches the one defined in the project settings, avoiding problems related to version mismatches.
Please refer to the [`asdf`](https://asdf-vm.com/guide/getting-started.html) documentation to install all prerequisites.

Once you have `asdf` installed locally, you can download `Scarb` plugin with the following command:

```bash
asdf plugin add scarb
```

This will allow you to download specific versions:

```bash
asdf install scarb 2.8.1
```

and set a global version:

```bash
asdf global scarb 2.8.1
```

You can verify installation by running the following command in a new terminal session, it should print both `Scarb` and `Cairo` language versions, e.g:

```javascript
$ scarb --version
scarb 2.8.1 (09590f5fc 2024-08-27)
cairo: 2.8.0 (https://crates.io/crates/cairo-lang-compiler/2.8.0)
sierra: 1.6.0
```
Reference: [`Cairo Book`](https://book.cairo-lang.org/ch01-01-installation.html)

### **Install `Foundry` for `Starknet`:**

Install via `snfoundryup`. `Snfoundryup` is the `Starknet Foundry` toolchain installer. You can install it by running:

```bash
curl -L https://raw.githubusercontent.com/foundry-rs/starknet-foundry/master/scripts/install.sh | sh
```

Follow the instructions and then run:

```bash
snfoundryup
```

See `snfoundryup --help` for more options.

To verify that the `Starknet Foundry` is installed correctly, run `snforge --version` and `sncast --version`.
Installation via `asdf`. First, add the `Starknet Foundry` plugin to `asdf`:

```bash
asdf plugin add starknet-foundry
```

Install the latest version:

```bash
asdf install starknet-foundry latest
```

See [`asdf guide`](https://asdf-vm.com/guide/getting-started.html) for more details.

Reference: [`The Starknet Foundry Book`](https://foundry-rs.github.io/starknet-foundry/getting-started/installation.html).

# Setup

Clone the repo

```bash
git clone .....
```

```bash
cd ....
```

Build and run tests

```bash
snforge test --features enable_for_tests
```

[//]: # (getting-started-close)

[//]: # (scope-open)

# Audit Scope Details

- In Scope:

```
src/
├── starknet_auction.cairo

```

The `mock_erc20_token.cairo` and `mock_erc721_token.cairo` contracts are used only in tests and are out of scope.

## Compatibilities

- Blockchains: Starknet
- Tokens: STRK

[//]: # (scope-close)

[//]: # (known-issues-open)

# Known Issues

- We can assume that the approval of the ERC721 and ERC20 tokens is done before the transfer.
- The protocol doesn't use safe_transfer_from when transfers the ERC721 token.

[//]: # (known-issues-close)