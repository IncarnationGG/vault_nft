// SPDX-License-Identifier: MIT

#[starknet::contract]
pub mod VaultNFTBasic {
    use openzeppelin::introspection::src5::SRC5Component;
    use openzeppelin::token::erc721::ERC721Component;
    use openzeppelin::token::erc721::extensions::ERC721EnumerableComponent;
    use openzeppelin::token::erc20::{ERC20ABIDispatcher, ERC20ABIDispatcherTrait};
    use starknet::{get_contract_address, get_caller_address};
    use starknet::{ContractAddress};
    use vault_nft::interfaces;

    component!(path: ERC721Component, storage: erc721, event: ERC721Event);
    component!(path: ERC721EnumerableComponent, storage: erc721_enumerable, event: ERC721EnumerableEvent);
    component!(path: SRC5Component, storage: src5, event: SRC5Event);

    #[storage]
    struct Storage {
        #[substorage(v0)]
        erc721: ERC721Component::Storage,
        #[substorage(v0)]
        erc721_enumerable: ERC721EnumerableComponent::Storage,
        #[substorage(v0)]
        src5: SRC5Component::Storage,
        asset: ContractAddress,
        total_assets: u256,
        base_price: u256,
        cur_token_id: u256,
    }

    #[event]
    #[derive(Drop, starknet::Event)]
    enum Event {
        #[flat]
        ERC721Event: ERC721Component::Event,
        #[flat]
        ERC721EnumerableEvent: ERC721EnumerableComponent::Event,
        #[flat]
        SRC5Event: SRC5Component::Event,
        Mint: Mint,
        Redeem: Redeem
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Mint {
        #[key]
        pub token_id: u256,
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub assets: u256
    }

    #[derive(Drop, PartialEq, starknet::Event)]
    pub struct Redeem {
        #[key]
        pub token_id: u256,
        #[key]
        pub owner: ContractAddress,
        #[key]
        pub assets: u256
    }

    // ERC721
    #[abi(embed_v0)]
    impl ERC721MixinImpl = ERC721Component::ERC721Impl<ContractState>;
    impl ERC721InternalImpl = ERC721Component::InternalImpl<ContractState>;

    // ERC721Enumerable
    #[abi(embed_v0)]
    impl ERC721EnumerableImpl = ERC721EnumerableComponent::ERC721EnumerableImpl<ContractState>;
    impl ERC721EnumerableInternalImpl = ERC721EnumerableComponent::InternalImpl<ContractState>;

    // SRC5
    #[abi(embed_v0)]
    impl SRC5Impl = SRC5Component::SRC5Impl<ContractState>;

    #[constructor]
    fn constructor(
        ref self: ContractState,
        name: ByteArray,
        symbol: ByteArray,
        base_uri: ByteArray,
        base_price: u256,
        asset: ContractAddress
    ) {
        self.asset.write(asset);
        self.base_price.write(base_price);
        self.erc721.initializer(name, symbol, base_uri);
        self.erc721_enumerable.initializer();
    }

    impl ERC721HooksImpl of ERC721Component::ERC721HooksTrait<ContractState> {
        fn before_update(
            ref self: ERC721Component::ComponentState<ContractState>,
            to: ContractAddress,
            token_id: u256,
            auth: ContractAddress
        ) {
            let mut contract_state = ERC721Component::HasComponent::get_contract_mut(ref self);
            contract_state.erc721_enumerable.before_update(to, token_id);
        }
    }

    #[abi(embed_v0)]
    pub impl VaultNFTImpl of interfaces::IVaultNFT<ContractState> {
        fn asset(self: @ContractState) -> ContractAddress {
            self.asset.read()
        }

        fn total_assets(self: @ContractState) -> u256 {
            self.total_assets.read()
        }

        fn convert_to_nft(self: @ContractState) -> u256 {
            self.base_price.read()
        }

        fn convert_to_assets(self: @ContractState, token_id: u256) -> u256 {
            self.base_price.read()
        }

        fn mint(ref self: ContractState) -> u256 {
            let assets = self.convert_to_nft();
            let caller = get_caller_address();
            let contract_address = get_contract_address();
            let asset = ERC20ABIDispatcher { contract_address: self.asset.read() };
            asset.transferFrom(caller, contract_address, assets);
            self.total_assets.write(self.total_assets.read() + assets);
            self.cur_token_id.write(self.cur_token_id.read() + 1);
            self.erc721.mint(caller, self.cur_token_id.read());
            self.emit(Mint { token_id: self.cur_token_id.read(), owner: caller, assets: assets });
            self.cur_token_id.read()
        }

        fn redeem(ref self: ContractState, token_id: u256) {
            let caller = get_caller_address();
            let assets = self.convert_to_assets(token_id);
            let asset = ERC20ABIDispatcher { contract_address: self.asset.read() };
            asset.transfer(caller, assets);
            self.total_assets.write(self.total_assets.read() - assets);
            self.erc721.burn(token_id);
            self.emit(Redeem { token_id: token_id, owner: caller, assets: assets });
        }
    }
}
