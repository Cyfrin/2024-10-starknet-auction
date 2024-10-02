// SPDX-License-Identifier: MIT
// Compatible with OpenZeppelin Contracts for Cairo ^0.16.0
use starknet::ContractAddress;

#[starknet::interface]
pub trait IMockERC20Token<TContractState> {
    fn mint(ref self: TContractState, recipient: ContractAddress, amount: u256);
    fn token_approve(ref self: TContractState, spender: ContractAddress, amount: u256);
    fn token_balance_of(self: @TContractState, account: ContractAddress) -> u256;
    fn token_allowance(self: @TContractState, owner: ContractAddress, spender: ContractAddress) -> u256;
}

#[starknet::contract]
#[cfg(feature: 'enable_for_tests')]
pub mod MockERC20Token {
    use ERC20Component::InternalTrait;
    use openzeppelin::token::erc20::{ERC20Component, ERC20HooksEmptyImpl};
    use starknet::{ContractAddress, get_caller_address};

    component!(path: ERC20Component, storage: erc20, event: ERC20Event);

    // ERC20 Mixin
    #[abi(embed_v0)]
    impl ERC20MixinImpl = ERC20Component::ERC20MixinImpl<ContractState>;
    impl ERC20InternalImpl = ERC20Component::InternalImpl<ContractState>;

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc20: ERC20Component::Storage
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC20Event: ERC20Component::Event
    }

    #[constructor]
    fn constructor(
        ref self: ContractState,
    ) {
        let name = "Starknet";
        let symbol = "STRK";

        self.erc20.initializer(name, symbol);
        
    }
    #[abi(embed_v0)]
    impl ERC20TokenImpl of super::IMockERC20Token<ContractState> {
    
        fn mint(
            ref self: ContractState,
            recipient: ContractAddress,
            amount: u256
        ) {
            self.erc20.mint(recipient, amount);
        }

        fn token_approve(ref self: ContractState, spender: ContractAddress, amount: u256) {
            let owner = get_caller_address();
            self.erc20._approve(owner, spender, amount);
        }

        fn token_balance_of(self: @ContractState, account: ContractAddress) -> u256 {
            let balance = self.erc20.balance_of(account);
            balance
        }

        fn token_allowance(self: @ContractState, owner: ContractAddress, spender: ContractAddress) -> u256 {
            let allowance = self.erc20.allowance(owner, spender);
            allowance
        }
    }
}