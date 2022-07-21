// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract Permissions is AccessControl {
    bytes32 public constant GOVERN_ROLE = keccak256("GOVERN_ROLE");
    bytes32 public constant GUARDIAN_ROLE = keccak256("GUARDIAN_ROLE");
    bytes32 public constant MASTER_ROLE = keccak256("MASTER_ROLE");

    constructor() public {
        _setupGovernor(address(this));
        _setRoleAdmin(GOVERN_ROLE, GOVERN_ROLE);
        _setRoleAdmin(GUARDIAN_ROLE, GOVERN_ROLE);
        _setRoleAdmin(MASTER_ROLE, GOVERN_ROLE);
    }

    modifier onlyGovernor() {
        require(
            isGovernor(msg.sender),
            "Permissions::onlyGovernor: Caller is not a governor"
        );
        _;
    }

    modifier onlyGuardian() {
        require(
            isGuardian(msg.sender),
            "Permissions::onlyGuardian: Caller is not a guardian"
        );
        _;
    }

    function createRole(bytes32 role, bytes32 adminRole)
        external
        onlyGovernor
    {
        _setRoleAdmin(role, adminRole);
    }

    function grantGovernor(address governor) external onlyGovernor {
        grantRole(GOVERN_ROLE, governor);
    }

    function grantGuardian(address guardian) external onlyGovernor {
        grantRole(GUARDIAN_ROLE, guardian);
    }

    function revokeGovernor(address governor) external onlyGovernor {
        revokeRole(GOVERN_ROLE, governor);
    }

    function revokeGuardian(address guardian) external onlyGovernor {
        revokeRole(GUARDIAN_ROLE, guardian);
    }

    function revokeOverride(bytes32 role, address account)
        external
        onlyGuardian
    {
        require(
            role != GOVERN_ROLE,
            "Permissions::revokeOverride: Guardian cannot revoke governor"
        );

        // External call because this contract is appointed as a governor and has access to revoke
        this.revokeRole(role, account);
    }

    function isGovernor(address _address)
        public
        view
        virtual
        returns (bool)
    {
        return hasRole(GOVERN_ROLE, _address);
    }

    function isGuardian(address _address) public view returns (bool) {
        return hasRole(GUARDIAN_ROLE, _address);
    }

    function _setupGovernor(address governor) internal {
        _setupRole(GOVERN_ROLE, governor);
    }
}