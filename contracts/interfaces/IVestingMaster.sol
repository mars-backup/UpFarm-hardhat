// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
pragma solidity 0.6.12;

interface IVestingMaster{
    function lock(address account, uint256 amount) external;

    function claim() external;

    function getVestingAmount() external view returns (uint256 lockedAmount, uint256 claimableAmount);

    function lockedPeriodAmount() external view returns (uint256 periodAmount);

    function vestingToken() external view returns (IERC20);

    function period() external view returns (uint256);

    function totalLockedRewards() external view returns (uint256);
}