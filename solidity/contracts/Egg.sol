import '@openzeppelin/token/ERC20/ERC20.sol'; //@audit named imports
import '@openzeppelin/token/ERC20/IERC20.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract Egg is ERC20, IEgg {
  address private _ants; //@audit can't inherit with private

  constructor(address __ants) ERC20('EGG', 'EGG') {
    _ants = __ants;
  }

  function mint(address _to, uint256 _amount) external override {
    //solhint-disable-next-line //@audit checks maybe?

    require(msg.sender == _ants, 'Only the ants contract can call this function, please refer to the ants contract'); //@audit custom errors
    _mint(_to, _amount);
  }

  function decimals() public view virtual override returns (uint8) {
    return 0;
  }
}
