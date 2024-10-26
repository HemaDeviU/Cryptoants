import '@openzeppelin/token/ERC721/ERC721.sol'; //@audit specify license always
import '@openzeppelin/token/ERC721/IERC721.sol'; //@audit named imports?
import '@openzeppelin/token/ERC20/IERC20.sol';
import 'forge-std/console.sol';

interface IEgg is IERC20 {
  function mint(address, uint256) external;
}

interface ICryptoAnts is IERC721 {
  event EggsBought(address, uint256);

  function notLocked() external view returns (bool);

  function buyEggs(uint256) external payable;
  //@audit other functions?

  error NoEggs();

  event AntSold();

  error NoZeroAddress();

  event AntCreated();

  error AlreadyExists();
  error WrongEtherSent();
}

//SPDX-License-Identifier: Unlicense
pragma solidity >=0.8.4 <0.9.0;

contract CryptoAnts is ERC721, ICryptoAnts {
  bool public locked = false;
  mapping(uint256 => address) public antToOwner;
  IEgg public immutable eggs; //@audit immutable caps
  uint256 public eggPrice = 0.01 ether;
  uint256[] public allAntsIds;
  bool public override notLocked = false; //@audit why override
  uint256 public antsCreated = 0;

  constructor(address _eggs) ERC721('Crypto Ants', 'ANTS') {
    eggs = IEgg(_eggs);
  }

  function buyEggs(uint256 _amount) external payable override lock {
    //@audit doesn't override
    uint256 _eggPrice = eggPrice;
    uint256 eggsCallerCanBuy = (msg.value / _eggPrice);
    eggs.mint(msg.sender, _amount); //@audit why not use eggcallercanbuy, why not check and revert
    emit EggsBought(msg.sender, eggsCallerCanBuy);
  }

  function createAnt() external {
    if (eggs.balanceOf(msg.sender) < 1) revert NoEggs();
    uint256 _antId = ++antsCreated;
    for (uint256 i = 0; i < allAntsIds.length; i++) {
      //@audit why?
      if (allAntsIds[i] == _antId) revert AlreadyExists();
    }
    _mint(msg.sender, _antId);
    antToOwner[_antId] = msg.sender;
    allAntsIds.push(_antId);
    emit AntCreated();
  }

  function sellAnt(uint256 _antId) external {
    //@audit reentrant
    require(antToOwner[_antId] == msg.sender, 'Unauthorized');
    // solhint-disable-next-line
    (bool success,) = msg.sender.call{value: 0.004 ether}(''); //@audit can't hardcode
    require(success, 'Whoops, this call failed!'); //@audit custom errors
    delete antToOwner[_antId]; //@audit checks pattern
    _burn(_antId);
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return antsCreated;
  }

  modifier lock() {
    //@audit modifier always at the top
    //solhint-disable-next-line
    require(locked == false, 'Sorry, you are not allowed to re-enter here :)');
    locked = true;
    _;
    locked = notLocked; //@audit why?
  }
}
//@audit governor to set prices?
//@audit withdraw?
//@audit better to have a pauseable contract
