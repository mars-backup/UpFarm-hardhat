// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "./LiquidityMiningMaster.sol";
import "../libs/TransferHelper.sol";

// Earn BNB
contract LiquidityMiningMasterBNB is LiquidityMiningMaster {
    using SafeMath for uint256;

    constructor(
        address _core,
        address _xmsAddress,
        address _vestingMaster,
        address _WBNB,
        uint256 _xmsPerBlock,
        uint256 _startBlock,
        uint256 _endBlock
    ) public
        LiquidityMiningMaster(
            _core,
            _xmsAddress,
            _vestingMaster,
            _WBNB,
            _xmsPerBlock,
            _startBlock,
            _endBlock
        )
    {}

    receive() external payable {}

    // Safe bnb transfer function, just in case if rounding error causes pool to not have enough bnb.
    function _safeTokenTransfer(address _to, uint256 _amount)
        internal
        override
        returns (uint256)
    {
        uint256 balance = address(this).balance;
        uint256 amount;
        if (_amount > balance) {
            amount = balance;
        } else {
            amount = _amount;
        }
        TransferHelper.safeTransferETH(_to, amount);
        return amount;
    }
}