// SPDX-License-Identifier: MIT

pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/utils/Pausable.sol";

interface ICore {
    function isGovernor(address _address) external view returns (bool);

    function isGuardian(address _address) external view returns (bool);

    function hasRole(bytes32 role, address account) external view returns (bool);
}

abstract contract CoreRef is Pausable {

    event CoreUpdate(address indexed _core);

    ICore private _core;

    bytes32 public constant MASTER_ROLE = keccak256("MASTER_ROLE");

    constructor(address core_) public {
        _core = ICore(core_);
    }

    modifier onlyGovernor() {
        require(
            _core.isGovernor(msg.sender),
            "CoreRef::onlyGovernor: Caller is not a governor"
        );
        _;
    }

    modifier onlyGuardian() {
        require(
            _core.isGuardian(msg.sender),
            "CoreRef::onlyGuardian: Caller is not a guardian"
        );
        _;
    }

    modifier onlyGuardianOrGovernor() {
        require(
            _core.isGovernor(msg.sender) || _core.isGuardian(msg.sender),
            "CoreRef::onlyGuardianOrGovernor: Caller is not a guardian or governor"
        );
        _;
    }

    modifier onlyMaster() {
        require(
            _core.hasRole(MASTER_ROLE, msg.sender),
            "CoreRef::onlyMaster: Caller is not a master"
        );
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(
            _core.hasRole(role, msg.sender),
            "CoreRef::onlyRole: Not permit"
        );
        _;
    }

    function setCore(address core_) external onlyGovernor {
        _core = ICore(core_);
        emit CoreUpdate(core_);
    }

    function pause() public onlyGuardianOrGovernor {
        _pause();
    }

    function unpause() public onlyGovernor {
        _unpause();
    }

    function core() public view returns (ICore) {
        return _core;
    }

}