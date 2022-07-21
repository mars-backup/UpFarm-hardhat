// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
pragma solidity ^0.6.12;
interface IWBNB is IERC20 {
    function deposit() external payable;

    function withdraw(uint256 wad) external;
}