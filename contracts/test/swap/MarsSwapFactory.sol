// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <0.8.0;

import "../interfaces/IMarsSwapFactory.sol";
import "./MarsSwapPair.sol";
import "../../refs/CoreRef.sol";

contract MarsSwapFactory is IMarsSwapFactory, CoreRef {
    address public override feeTo;
    uint256 public override feeScale = 997;
    uint256 public override feeStakeScale = 5;
    address[] public override allPairs;

    mapping(address => uint256) public feeSpec;

    mapping(address => mapping(address => address)) public override getPair;

    constructor(address _core) public CoreRef(_core) {
        feeTo = _core;
    }

    function getPairInitCode() public pure returns (bytes32) {
        return keccak256(abi.encodePacked(type(MarsSwapPair).creationCode));
    }

    function fee(address _pair)
        external
        view
        override
        returns (
            address,
            bool,
            uint256
        )
    {
        require(_pair != address(0), "MarsSwapFactory::fee: Zero address");
        uint256 _feeScale = feeScale;
        if (feeTo == address(0)) {
            _feeScale = 1000;
        } else if (feeSpec[_pair] > 0) {
            _feeScale = feeSpec[_pair];
        }
        return (feeTo, _feeScale != 1000, _feeScale);
    }

    function allPairsLength() external view override returns (uint256) {
        return allPairs.length;
    }

    function createPair(address tokenA, address tokenB)
        external
        override
        returns (address pair)
    {
        require(
            tokenA != tokenB,
            "MarsSwapFactory::createPair: Identical addresses"
        );
        (address token0, address token1) =
            tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(
            token0 != address(0),
            "MarsSwapFactory::createPair: Zero address"
        );
        require(
            getPair[token0][token1] == address(0),
            "MarsSwapFactory::createPair: Pair exists"
        ); // Single check is sufficient
        bytes memory bytecode = type(MarsSwapPair).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(token0, token1));
        assembly {
            pair := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        IMarsSwapPair(pair).initialize(token0, token1);
        getPair[token0][token1] = pair;
        getPair[token1][token0] = pair; // Populate mapping in the reverse direction
        allPairs.push(pair);
        emit PairCreated(token0, token1, pair, allPairs.length);
    }

    function setFeeTo(address _feeTo) external override onlyGovernor {
        feeTo = _feeTo;
    }

    function setFeeScale(uint256 _feeScale) external override onlyGovernor {
        require(
            _feeScale < 1000,
            "MarsSwapFactory::setFeeScale: Error feeScale"
        );
        feeScale = _feeScale;
    }

    function setFeeStakeScale(uint256 _feeStakeScale)
        external
        override
        onlyGovernor
    {
        require(
            _feeStakeScale < 100 && _feeStakeScale > 0,
            "MarsSwapFactory::setFeeStakeScale: Error feeStakeScale"
        );
        feeStakeScale = _feeStakeScale;
    }

    function setFeeSpec(address _pair, uint256 _feeScale)
        external
        override
        onlyGovernor
    {
        require(
            _feeScale < 1000,
            "MarsSwapFactory::setFeeSpec: Error feeScale"
        );
        feeSpec[_pair] = _feeScale;
    }

    function setFeeNoSpec() external override onlyGovernor {
        require(allPairs.length > 0, "MarsSwapFactory::setFeeNoSpec: No pairs");
        for (uint256 i = 0; i < allPairs.length; i++) {
            delete feeSpec[allPairs[i]];
        }
    }
}
