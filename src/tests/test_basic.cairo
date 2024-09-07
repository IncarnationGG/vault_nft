use starknet::{ContractAddress, contract_address_const, get_caller_address, get_contract_address};
use openzeppelin::utils::serde::SerializedAppend;
use openzeppelin::token::erc721::{ERC721ABIDispatcher, ERC721ABIDispatcherTrait};
use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};

use snforge_std::{declare, ContractClassTrait, DeclareResultTrait, start_cheat_caller_address};

use vault_nft::interfaces::IVaultNFTDispatcher;
use vault_nft::interfaces::IVaultNFTDispatcherTrait;
use vault_nft::interfaces::IVaultNFTSafeDispatcherTrait;

fn deploy_contract(name: ByteArray, calldata: @Array<felt252>) -> ContractAddress {
    let contract = declare(name).unwrap().contract_class();
    let (contract_address, _) = contract.deploy(calldata).unwrap();
    contract_address
}

fn deploy_erc20() -> ContractAddress {
    let mut calldata = array![];
    let contract = declare("MyToken").unwrap().contract_class();
    let (contract_address, _) = contract.deploy(@calldata).unwrap();
    contract_address
}

#[test]
fn test_mint() {
    let erc20_address:ContractAddress = deploy_erc20();
    // start_cheat_caller_address(erc20_address, contract_address_const::<0x049D36570D4e46f48e99674bd3fcc84644DdD6b96F7C741B1562B82f9e004dC7>());
    let mut calldata = array![];
    let name: ByteArray = "VaultNFT";
    let symbol: ByteArray = "VaultNFT";
    let url: ByteArray = "api";
    let base_price: u256 = 100000000000000;
    calldata.append_serde(name);
    calldata.append_serde(symbol);
    calldata.append_serde(url);
    calldata.append_serde(base_price);
    calldata.append_serde(erc20_address);
    let contract_address = deploy_contract("VaultNFTBasic", @calldata);
    // println!("contract_address:{:?}", contract_address);
    let dispatcher_erc20 = ERC20ABIDispatcher { contract_address: erc20_address };
    dispatcher_erc20.approve(contract_address, 100000000000000);
    let dispatcher_vault_nft = IVaultNFTDispatcher { contract_address };    
    let token_id = dispatcher_vault_nft.mint();
    let dispatcher_erc721 = ERC721ABIDispatcher { contract_address };
    let caller:ContractAddress = get_contract_address();
    assert(dispatcher_erc721.balance_of(caller) == 1, 'Invalid balance');
    assert(dispatcher_erc721.owner_of(token_id) == caller, 'Invalid owner');
}

#[test]
#[feature("safe_dispatcher")]
fn test_cannot_increase_balance_with_zero_value() {
    // let contract_address = deploy_contract("HelloStarknet");

    // let safe_dispatcher = IHelloStarknetSafeDispatcher { contract_address };

    // let balance_before = safe_dispatcher.get_balance().unwrap();
    // assert(balance_before == 0, 'Invalid balance');

    // match safe_dispatcher.increase_balance(0) {
    //     Result::Ok(_) => core::panic_with_felt252('Should have panicked'),
    //     Result::Err(panic_data) => {
    //         assert(*panic_data.at(0) == 'Amount cannot be 0', *panic_data.at(0));
    //     }
    // };
}
