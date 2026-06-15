// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.24;

import {ITown} from "./interfaces/ITown.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {
    ERC20Permit
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {
    ERC20Capped
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

import {
    ERC20Burnable
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

/// @title TOWN
/// @author TownSquare, Solidly
/// @notice The native token in the TownSquare ecosystem
/// @dev Emitted by the Minter
contract Town is ITown, ERC20Permit, ERC20Capped, AccessControl, ERC20Burnable {
    address public tokenMinter;

    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    address public ccipAdmin;

    address public pendingCCIPAdmin;

    error NotAuthorized(address sender);
    error ZeroAddress();

    event CCIPAdminTransferred(
        address indexed previousAdmin,
        address indexed newAdmin
    );

    constructor(
        uint256 initialMint,
        address _ccipAdmin
    )
        ERC20("TownSquare", "TOWN")
        ERC20Permit("TownSquare")
        ERC20Capped(10_000_000_000 ether)
    {
        tokenMinter = _msgSender();
        _mint(tokenMinter, initialMint);
        _grantRole(DEFAULT_ADMIN_ROLE, _ccipAdmin);
        ccipAdmin = _ccipAdmin;
    }

    function _update(
        address from,
        address to,
        uint256 value
    ) internal virtual override(ERC20, ERC20Capped) {
        super._update(from, to, value);
    }

    /// @inheritdoc ERC20Burnable
    /// @dev Uses OZ ERC20 _burn to disallow burning from address(0).
    /// @dev Decreases the total supply.
    function burn(
        uint256 amount
    ) public virtual override(ERC20Burnable) onlyRole(BURNER_ROLE) {
        super.burn(amount);
    }

    /// @dev Alias for BurnFrom for compatibility with the older naming convention.
    /// @dev Uses burnFrom for all validation & logic.
    function burn(
        address account,
        uint256 amount
    ) public onlyRole(BURNER_ROLE) {
        burnFrom(account, amount);
    }

    /// @inheritdoc ERC20Burnable
    /// @dev Uses OZ ERC20 _burn to disallow burning from address(0).
    /// @dev Decreases the total supply.
    function burnFrom(
        address account,
        uint256 amount
    ) public virtual override(ERC20Burnable) onlyRole(BURNER_ROLE) {
        super.burnFrom(account, amount);
    }

    /// @dev Uses OZ ERC20 _mint to disallow minting to address(0).
    /// @dev Disallows minting to address(this)
    /// @dev Increases the total supply.
    function mint(
        address account,
        uint256 amount
    ) external onlyRole(MINTER_ROLE) {
        _mint(account, amount);
    }

    function grantMintAndBurnRoles(
        address burnAndMinter
    ) external virtual onlyRole(DEFAULT_ADMIN_ROLE) {
        grantRole(MINTER_ROLE, burnAndMinter);
        grantRole(BURNER_ROLE, burnAndMinter);
    }

    function getCCIPAdmin() external view virtual returns (address) {
        return ccipAdmin;
    }

    function setCCIPAdmin(
        address newAdmin
    ) public onlyRole(DEFAULT_ADMIN_ROLE) {
        if (newAdmin == address(0)) revert ZeroAddress();
        pendingCCIPAdmin = newAdmin;
    }

    function acceptCCIPAdmin() public {
        address sender = _msgSender();
        if (pendingCCIPAdmin != sender) {
            revert NotAuthorized(sender);
        }
        address previousAdmin = ccipAdmin;
        _revokeRole(DEFAULT_ADMIN_ROLE, previousAdmin);
        delete pendingCCIPAdmin;
        _grantRole(DEFAULT_ADMIN_ROLE, sender);
        ccipAdmin = sender;
        emit CCIPAdminTransferred(previousAdmin, sender);
    }
}
