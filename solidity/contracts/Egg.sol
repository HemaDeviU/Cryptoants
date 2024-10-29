//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.20;

import {ERC20} from '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {Ownable} from '@openzeppelin/contracts/access/Ownable.sol';
import {ERC20Pausable} from '@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
  function burnEgg(address, uint256) external;
  function decimals() external view returns (uint8);
}

contract Egg is ERC20, IEgg, Ownable, ERC20Pausable {
  error Egg_ZeroAddress();
  error Egg_UnauthorizedMint();
  error Egg_IncorrectAmount();

  address private immutable _I_ANTS;

  constructor(address __ants) ERC20('Egg', 'EGG') Ownable(msg.sender) {
    if (__ants == address(0)) {
      revert Egg_ZeroAddress();
    }
    _I_ANTS = __ants;
  }

  modifier onlyAnts() {
    if (msg.sender != _I_ANTS) {
      revert Egg_UnauthorizedMint();
    }
    _;
  }

  function mint(address _to, uint256 _amount) external override onlyAnts {
    //solhint-disable-next-line

    if (_amount == 0) {
      revert Egg_IncorrectAmount();
    }
    _mint(_to, _amount);
  }

  function burnEgg(address _from, uint256 _amount) external onlyAnts {
    _burn(_from, _amount);
  }

  function decimals() public view virtual override(ERC20, IEgg) returns (uint8) {
    return 0;
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

  // The following functions are overrides required by Solidity.

  function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Pausable) {
    super._update(from, to, value);
  }
}
