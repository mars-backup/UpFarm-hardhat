// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;

interface IMarsSwapFactory {
    // ----------- Events -----------

    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    // ----------- State changing api -----------

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);

    // ----------- Governor only state changing API -----------

    function setFeeTo(address) external;

    function setFeeScale(uint256) external;

    function setFeeStakeScale(uint256) external;

    function setFeeSpec(address pair, uint256 _feeScale) external;

    function setFeeNoSpec() external;

    // ----------- Getters -----------

    function fee(address pair)
        external
        view
        returns (
            address,
            bool,
            uint256
        );

    function feeTo() external view returns (address);

    function feeScale() external view returns (uint256);

    function feeStakeScale() external view returns (uint256);

    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);
}
