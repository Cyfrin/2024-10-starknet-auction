use snforge_std::{ declare, load, map_entry_address, ContractClassTrait, DeclareResultTrait };
use snforge_std::{ start_cheat_caller_address_global, stop_cheat_caller_address_global, start_cheat_block_timestamp, stop_cheat_block_timestamp, start_cheat_caller_address, stop_cheat_caller_address};
use core::traits::TryInto;
use core::serde::Serde;
use starknet::ContractAddress;
use openzeppelin::token::erc721::interface::{IERC721Dispatcher, IERC721DispatcherTrait};
use starknet_auction::starknet_auction::IStarknetAuctionDispatcher;
use starknet_auction::starknet_auction::IStarknetAuctionDispatcherTrait;
use starknet_auction::mock_erc20_token::IMockERC20TokenDispatcher;
use starknet_auction::mock_erc20_token::IMockERC20TokenDispatcherTrait;
use starknet::{get_caller_address, get_contract_address, get_block_timestamp};

fn deploy_auction_contract() -> (IStarknetAuctionDispatcher, ContractAddress, ContractAddress, ContractAddress) {
    // Declare Starknet Auction contract.
    let contract = declare("StarknetAuction").unwrap().contract_class();
    // Define arguments.
    let mut calldata = ArrayTrait::new();
    
    // Declare and deploy the NFT token contract.
    let erc721_contract = declare("MockERC721Token").unwrap().contract_class();
    let mut erc721_args = ArrayTrait::new();
    let recipient = get_contract_address();
    (recipient, ).serialize(ref erc721_args);
    let (erc721_contract_address, _) = erc721_contract.deploy(@erc721_args).unwrap();

    // Declare and deploy the ERC20 token contract. 
    let erc20_contract = declare("MockERC20Token").unwrap().contract_class();
    let mut erc20_args = ArrayTrait::new();
    let (erc20_contract_address, _) = erc20_contract.deploy(@erc20_args).unwrap();
    
    let nft_id = 1;
    (erc20_contract_address, erc721_contract_address, nft_id, ).serialize(ref calldata);
    // Deploy the Auction contract.
    let (contract_address, _) = contract.deploy(@calldata).unwrap();

    // Create a Dispatcher object that will allow interacting with the deployed Auction contract.
    let dispatcher = IStarknetAuctionDispatcher { contract_address: contract_address };
    // Create a Dispatcher object that will allow interacting with the deployed NFT contract.
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    erc721_dispatcher.approve(contract_address, 1);
    
    (dispatcher, contract_address, erc20_contract_address, erc721_contract_address)
}

#[test]
fn test_deployment() {    
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();
    let nft_id = load(auction_contract, selector!("nft_id"), 1);
    assert(nft_id == array![1], 'nft_id == 1');
}

#[test]
fn test_start() {
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();
    
    // The bid after deployment.
    let mut bid = auction_dispatcher.get_bid();
    assert(bid == 0, 'Bid must be 0 ');
    
    // The owner calls start function.
    auction_dispatcher.start(86400, 10);
    
    // The bid after calling the start function must be 10.
    bid = auction_dispatcher.get_bid();
    assert(bid == 10, 'Bid must be 10');

    let started = load(auction_contract, selector!("started"), 1);
    assert(*started.at(0) == 1, 'Started must be true');

    let highest_bid = load(auction_contract, selector!("highest_bid"), 1);
    assert(highest_bid == array![10], 'Highest bid must be 10');

    let starting_price = load(auction_contract, selector!("starting_price"), 1);
    assert(starting_price == array![10], 'Highest bid must be 10');

    let bidding_end = load(auction_contract, selector!("bidding_end"), 1);
    let time = get_block_timestamp();
    assert(bidding_end == array![time.into() + 86400], 'Incorrect bidding end!');
}

#[test]
#[should_panic(expected: 'Not the nft owner')]
fn test_start_unauthorized_caller() {
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();
    //Change the caller.
    start_cheat_caller_address(auction_contract, 123.try_into().unwrap());
    // The non-owner calls start function.
    auction_dispatcher.start(86400, 10);
    stop_cheat_caller_address(auction_contract);
}

#[test]
#[should_panic(expected: 'The bid is not sufficient')]
fn test_bid_unsufficient_bid() {
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();
        
    // The owner calls start function.
    auction_dispatcher.start(86400, 10);

    start_cheat_caller_address(auction_contract, 123.try_into().unwrap());
    auction_dispatcher.bid(5);
    stop_cheat_caller_address(auction_contract);
}

#[test]
#[should_panic(expected: 'Auction is not started')]
fn test_bid_auction_is_not_started() {
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();

    start_cheat_caller_address(auction_contract, 123.try_into().unwrap());
    auction_dispatcher.bid(15);
    stop_cheat_caller_address(auction_contract);
}

#[test]
#[should_panic(expected: 'Auction ended')]
fn test_bid_auction_ended() {
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();
        
    // The owner calls start function.
    auction_dispatcher.start(86400, 10);
    
    let time = get_block_timestamp();
    //Change the blocktimestamp.
    start_cheat_block_timestamp(auction_contract, time + 86401);

    start_cheat_caller_address(auction_contract, 123.try_into().unwrap());
    auction_dispatcher.bid(15);
    stop_cheat_caller_address(auction_contract);
    stop_cheat_block_timestamp(auction_contract);
}

#[test]
fn test_bid() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, _) = deploy_auction_contract();
    //The owner calls the start function and the auction begins.
    auction_dispatcher.start(86400, 10);

    let erc20_dispatcher = IMockERC20TokenDispatcher { contract_address: erc20_contract_address };
    //Change the caller address
    let first_bidder_address: ContractAddress = 123.try_into().unwrap();
    start_cheat_caller_address_global(first_bidder_address);
    
    erc20_dispatcher.mint(first_bidder_address, 20);
    let balance = erc20_dispatcher.token_balance_of(first_bidder_address);
    assert(balance == 20, 'Balance must be 20');

    erc20_dispatcher.token_approve(auction_contract, 20);
        
    //The first bidder calls the bid function with amount of 11.
    auction_dispatcher.bid(11);
    stop_cheat_caller_address_global();
    
    //Check the balance of the auction contract.
    let balance_auction_contract = erc20_dispatcher.token_balance_of(auction_contract);
    assert(balance_auction_contract == 11, 'The balance must be 11');

    // Check the balance of the first bidder after bidding.
    let balance_first_bidder_after = erc20_dispatcher.token_balance_of(first_bidder_address);
    assert(balance_first_bidder_after == 9, 'The balance must be 9');

    // Define the second bidder address
    let second_bidder_address: ContractAddress = 111.try_into().unwrap();
    start_cheat_caller_address_global(second_bidder_address);
    
    erc20_dispatcher.mint(second_bidder_address, 15);
    let balance_second_bidder = erc20_dispatcher.token_balance_of(second_bidder_address);
    assert(balance_second_bidder == 15, 'Balance must be 15');

    erc20_dispatcher.token_approve(auction_contract, 15);
       
    //The second bidder calls the bid function with amount of 15.
    auction_dispatcher.bid(15);

    stop_cheat_caller_address_global();

    //Check the balance of the auction contract.
    let balance_auction_contract = erc20_dispatcher.token_balance_of(auction_contract);
    assert(balance_auction_contract == 26, 'The balance must be 26');

    // Check the balance of the second bidder after bidding.
    let balance_second_bidder_after = erc20_dispatcher.token_balance_of(second_bidder_address);
    assert(balance_second_bidder_after == 0, 'The balance must be 0');

    let highest_bid = load(auction_contract, selector!("highest_bid"), 1);
    assert(highest_bid == array![15], 'Highest bid must be 15');

    let values = load(auction_contract, map_entry_address(selector!("bid_values"), array![first_bidder_address.try_into().unwrap()].span(), ), 1, );
    assert(*values.at(0) == 11, 'Incorrect return value!');
}

#[test]
#[should_panic(expected: 'Auction is not started')]
fn test_call_end_before_auction_started() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, _) = deploy_auction_contract();
    auction_dispatcher.end();
}

#[test]
#[should_panic(expected: 'Auction is not yet ended')]
fn test_call_end_before_auction_ended() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, _) = deploy_auction_contract();

    // The owner calls start function.
    auction_dispatcher.start(86400, 10);
    
    let time = get_block_timestamp();
    //Change the blocktimestamp.
    start_cheat_block_timestamp(auction_contract, time + 83400);
    auction_dispatcher.end();
    stop_cheat_block_timestamp(auction_contract);
}

#[test]
#[should_panic(expected: 'Auction end is already called')]
fn test_call_end_already_called() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, erc721_contract_address) = deploy_auction_contract();
        
    // The owner calls start function.
    auction_dispatcher.start(86400, 10);
    
    let erc20_dispatcher = IMockERC20TokenDispatcher { contract_address: erc20_contract_address };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    //Change the caller address
    let first_bidder_address: ContractAddress = 123.try_into().unwrap();
    start_cheat_caller_address_global(first_bidder_address);
    
    erc20_dispatcher.mint(first_bidder_address, 20);
    erc20_dispatcher.token_approve(auction_contract, 20);    
    //The first bidder calls the bid function with amount of 15.
    auction_dispatcher.bid(15);
    stop_cheat_caller_address_global();

    let highest_bid = load(auction_contract, selector!("highest_bid"), 1);
    assert(highest_bid == array![15], 'Highest bid must be 15');

    let starting_price = load(auction_contract, selector!("starting_price"), 1);
    assert(starting_price == array![10], 'Starting price must be 10');

    start_cheat_caller_address_global(auction_contract);
    erc721_dispatcher.approve(first_bidder_address, 1);
    stop_cheat_caller_address_global();

    let time = get_block_timestamp();
    //Change the blocktimestamp.
    start_cheat_block_timestamp(auction_contract, time + 86401);
    auction_dispatcher.end();

    let ended = load(auction_contract, selector!("ended"), 1);
    assert(*ended.at(0) == 1, 'Ended must be true');

    auction_dispatcher.end();
    stop_cheat_block_timestamp(auction_contract);
}

#[test]
#[should_panic(expected: 'No bids')]
fn test_call_end_no_bids() {
    let (auction_dispatcher, auction_contract, _, _) = deploy_auction_contract();
        
    // The owner calls start function.
    auction_dispatcher.start(86400, 10);
    
    let time = get_block_timestamp();
    start_cheat_block_timestamp(auction_contract, time + 86401);
    auction_dispatcher.end();
    stop_cheat_block_timestamp(auction_contract);
}

#[test]
fn test_call_end() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, erc721_contract_address) = deploy_auction_contract();
    //The owner calls the start function and the auction begins.
    auction_dispatcher.start(86400, 10);

    let erc20_dispatcher = IMockERC20TokenDispatcher { contract_address: erc20_contract_address };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    //Change the caller address
    let first_bidder_address: ContractAddress = 123.try_into().unwrap();
    start_cheat_caller_address_global(first_bidder_address);
    
    erc20_dispatcher.mint(first_bidder_address, 20);
    erc20_dispatcher.token_approve(auction_contract, 20);
        
    //The first bidder calls the bid function with amount of 11.
    auction_dispatcher.bid(11);
    stop_cheat_caller_address_global();
    
    // Define the second bidder address
    let second_bidder_address: ContractAddress = 111.try_into().unwrap();
    start_cheat_caller_address_global(second_bidder_address);
    
    erc20_dispatcher.mint(second_bidder_address, 15);
    erc20_dispatcher.token_approve(auction_contract, 15);
        
    //The second bidder calls the bid function with amount of 15.
    auction_dispatcher.bid(15);

    stop_cheat_caller_address_global();

    let time = get_block_timestamp();
    start_cheat_block_timestamp(auction_contract, time + 86401);

    start_cheat_caller_address_global(auction_contract);
    erc721_dispatcher.approve(second_bidder_address, 1);
    stop_cheat_caller_address_global();
    
    let nft_balance = erc721_dispatcher.balance_of(auction_contract);
    assert(nft_balance == 1, 'Nft balance must be 1');

    auction_dispatcher.end();

    let nft_balance_highest_bidder = erc721_dispatcher.balance_of(second_bidder_address);
    assert(nft_balance_highest_bidder == 1, 'Nft balance of bidder must be 1');

    let nft_balance_auction_contract = erc721_dispatcher.balance_of(auction_contract);
    assert(nft_balance_auction_contract == 0, 'Nft balance must be 0');
    
    stop_cheat_block_timestamp(auction_contract);
}


#[test]
#[should_panic(expected: 'Auction is not started')]
fn test_withdraw_auction_not_started() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, _) = deploy_auction_contract();
    auction_dispatcher.withdraw();
}

#[test]
#[should_panic(expected: 'Auction is not ended')]
fn test_withdraw_auction_not_ended() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, _) = deploy_auction_contract();
    auction_dispatcher.start(86400, 10);
    auction_dispatcher.withdraw();
}


#[test]
fn test_withdraw_called_owner() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, erc721_contract_address) = deploy_auction_contract();
    //The owner calls the start function and the auction begins.
    auction_dispatcher.start(86400, 10);

    let erc20_dispatcher = IMockERC20TokenDispatcher { contract_address: erc20_contract_address };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    //Change the caller address
    let first_bidder_address: ContractAddress = 123.try_into().unwrap();
    start_cheat_caller_address_global(first_bidder_address);
    
    erc20_dispatcher.mint(first_bidder_address, 20);
    erc20_dispatcher.token_approve(auction_contract, 20);
        
    //The first bidder calls the bid function with amount of 11.
    auction_dispatcher.bid(11);
    stop_cheat_caller_address_global();
    
    // Define the second bidder address
    let second_bidder_address: ContractAddress = 111.try_into().unwrap();
    start_cheat_caller_address_global(second_bidder_address);
    
    erc20_dispatcher.mint(second_bidder_address, 15);
    erc20_dispatcher.token_approve(auction_contract, 15);
        
    //The second bidder calls the bid function with amount of 15.
    auction_dispatcher.bid(15);

    stop_cheat_caller_address_global();

    let time = get_block_timestamp();
    start_cheat_block_timestamp(auction_contract, time + 86401);

    let owner = get_contract_address();
    start_cheat_caller_address_global(auction_contract);
    erc20_dispatcher.token_approve(owner, 15);
    erc721_dispatcher.approve(second_bidder_address, 1);
    stop_cheat_caller_address_global();
    
    auction_dispatcher.end();
    
    start_cheat_caller_address_global(owner);
    auction_dispatcher.withdraw();
    stop_cheat_caller_address_global();

    //Check the balance of the owner.
    let erc20_balance_owner = erc20_dispatcher.token_balance_of(owner);
    assert(erc20_balance_owner == 15, 'Balance must be 15');
    
    stop_cheat_block_timestamp(auction_contract);
}

#[test]
fn test_withdraw_called_bidder() {
    let (auction_dispatcher, auction_contract, erc20_contract_address, erc721_contract_address) = deploy_auction_contract();
    //The owner calls the start function and the auction begins.
    auction_dispatcher.start(86400, 10);

    let erc20_dispatcher = IMockERC20TokenDispatcher { contract_address: erc20_contract_address };
    let erc721_dispatcher = IERC721Dispatcher { contract_address: erc721_contract_address };
    //Change the caller address
    let first_bidder_address: ContractAddress = 123.try_into().unwrap();
    start_cheat_caller_address_global(first_bidder_address);
    
    erc20_dispatcher.mint(first_bidder_address, 20);
    erc20_dispatcher.token_approve(auction_contract, 20);
        
    //The first bidder calls the bid function with amount of 11.
    auction_dispatcher.bid(11);
    stop_cheat_caller_address_global();
    
    // Define the second bidder address
    let second_bidder_address: ContractAddress = 111.try_into().unwrap();
    start_cheat_caller_address_global(second_bidder_address);
    
    erc20_dispatcher.mint(second_bidder_address, 15);
    erc20_dispatcher.token_approve(auction_contract, 15);
        
    //The second bidder calls the bid function with amount of 15.
    auction_dispatcher.bid(15);

    stop_cheat_caller_address_global();

    let time = get_block_timestamp();
    start_cheat_block_timestamp(auction_contract, time + 86401);

    start_cheat_caller_address_global(auction_contract);
    erc20_dispatcher.token_approve(first_bidder_address, 11);
    erc721_dispatcher.approve(second_bidder_address, 1);
    stop_cheat_caller_address_global();
    
    auction_dispatcher.end();

    start_cheat_caller_address_global(first_bidder_address);
    auction_dispatcher.withdraw();
    stop_cheat_caller_address_global();
    
    //Check the balance of the bidder after withdraw
    let erc20_balance_bidder = erc20_dispatcher.token_balance_of(first_bidder_address);
    assert(erc20_balance_bidder == 20, 'Balance must be 20');
    
    stop_cheat_block_timestamp(auction_contract);
}

