// SPDX-License-Identifier: MIT

#[starknet::interface]
pub trait IStarknetAuction<TContractState> {
    fn start(ref self: TContractState, bidding_duration: u64, starting_bid: u64);
    fn bid(ref self: TContractState, amount: u64);
    fn withdraw(ref self: TContractState);
    fn end(ref self: TContractState);
    fn get_bid(self: @TContractState) -> u64;
}

#[starknet::contract]
pub mod StarknetAuction {
    use core::starknet::event::EventEmitter;
    use starknet::{ContractAddress, get_caller_address, get_contract_address, get_block_timestamp};
    use starknet::storage::{ StoragePointerReadAccess, StoragePointerWriteAccess, StoragePathEntry, Map };
    use openzeppelin::token::erc20::interface::{IERC20Dispatcher, IERC20DispatcherTrait};
    use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
    
    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        Started: Started,
        NewHighestBid: NewHighestBid,
        Withdraw: Withdraw,
        End: End,
    }

    #[derive(Drop, starknet::Event)]
    struct Started {}

    #[derive(Drop, starknet::Event)]
    struct NewHighestBid {
        amount: u64,
        sender: ContractAddress,
    }
    
    #[derive(Drop, starknet::Event)]
    struct Withdraw {
        amount: u64,
        caller: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    struct End {
        highest_bid: u64,
        highest_bidder: ContractAddress,
    }

    #[storage]
    struct Storage {
        nft_id: u64,
        highest_bid: u64,
        starting_price: u64,
        bidding_end: u64,
        highest_bidder: ContractAddress,
        nft_owner: ContractAddress,
        erc721_token: ContractAddress,
        erc20_token: ContractAddress,
        ended: bool,
        started: bool,
        bid_values: Map<ContractAddress, u64>,       
    }

    #[constructor]
    fn constructor(ref self: ContractState, erc20_token: ContractAddress, erc721_token: ContractAddress, _nft_id: u64) {  
        let caller = get_caller_address();

        self.erc20_token.write(erc20_token);
        self.erc721_token.write(erc721_token);
        self.nft_id.write(_nft_id);
        self.nft_owner.write(caller);
    }

    #[abi(embed_v0)]
    impl AuctionImpl of super::IStarknetAuction<ContractState> {
        fn start(ref self: ContractState, bidding_duration: u64, starting_bid: u64) {
            let caller = get_caller_address();
            let time = get_block_timestamp();
            let bidding_end = time + bidding_duration;
            let erc721_dispatcher = IERC721Dispatcher { contract_address: self.erc721_token.read() };
            let receiver = get_contract_address();
            
            assert(!self.started.read(), 'Auction is already started');
            assert(caller == self.nft_owner.read(), 'Not the nft owner');

            self.bidding_end.write(bidding_end);
            self.started.write(true);
            self.highest_bid.write(starting_bid);
            self.starting_price.write(starting_bid);
            self.highest_bidder.write(caller);
            self.emit(Started{});
            
            erc721_dispatcher.transfer_from(caller, receiver, self.nft_id.read().into());
        }

        fn bid(ref self: ContractState, amount: u64) {
            let time = get_block_timestamp();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.erc20_token.read() };
            let sender = get_caller_address();
            let receiver = get_contract_address();
            let current_bid = self.highest_bid.read();
            
            assert(self.started.read(), 'Auction is not started');
            assert(time < self.bidding_end.read(), 'Auction ended');
            assert(amount > current_bid, 'The bid is not sufficient');
            
            self.bid_values.entry(sender).write(amount);
            self.emit(NewHighestBid {amount: self.highest_bid.read(), sender: sender});
            self.highest_bidder.write(sender);
            self.highest_bid.write(amount);      
            
            erc20_dispatcher.transfer(receiver, amount.into());   
        }

        fn withdraw(ref self: ContractState) {
            assert(self.started.read(), 'Auction is not started');
            assert(self.ended.read(), 'Auction is not ended');
            
            let caller = get_caller_address();
            let sender = get_contract_address();
            let erc20_dispatcher = IERC20Dispatcher { contract_address: self.erc20_token.read() };
            let amount = self.bid_values.entry(caller).read();
            let amount_owner = self.highest_bid.read();
            
            if caller == self.nft_owner.read() {
                self.highest_bid.write(0);
                erc20_dispatcher.transfer_from(sender, caller, amount_owner.into());
            }

            if amount > 0 {
                let sender = get_contract_address();
                erc20_dispatcher.transfer_from(sender, caller, amount.into());
            }

            self.emit(Withdraw {amount: amount, caller: caller});
        }

        fn end(ref self: ContractState) {
            let time = get_block_timestamp();
            let caller = get_caller_address();
            let erc721_dispatcher = IERC721Dispatcher { contract_address: self.erc721_token.read() };
            let sender = get_contract_address();
            
            assert(caller == self.nft_owner.read(), 'Not the nft owner');
            assert(self.started.read(), 'Auction is not started');
            assert(time >= self.bidding_end.read(), 'Auction is not yet ended');
            assert(!self.ended.read(), 'Auction end is already called');
            assert(self.starting_price.read() < self.highest_bid.read(), 'No bids');
            
            self.ended.write(true);
            self.emit(End {highest_bid: self.highest_bid.read(), highest_bidder: self.highest_bidder.read()});
            
            erc721_dispatcher.transfer_from(sender, self.highest_bidder.read(), self.nft_id.read().into());
        }
        
        fn get_bid(self: @ContractState) -> u64 {
            self.highest_bid.read()
        }
    }
}

