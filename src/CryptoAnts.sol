//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.20;

import {IEgg} from './Egg.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {ERC721Pausable} from '@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol';
import {VRFConsumerBaseV2Plus} from '@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol';
import {VRFV2PlusClient} from '@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol';
import {console} from 'forge-std/console.sol';



interface ICryptoAnts is IERC721 {
  function buyEggs(uint256 _numberOfEggs) external payable;
  function createAnt() external returns (uint256 _antId);
  function sellAnt(uint256 _antId,uint256 amount) external;
  function layEggs(uint256 _antId) external returns (uint256 requestId);
  function setPrice(uint256 newPrice) external;
  function getAntPrice() external view returns (uint256);
  function isAlive(uint256 antId) external view returns (bool);
}
/* @Title CryptoAnts
@Author Hema
@notice The contract allows users to buy eggs, create ants and use the ants to lay new eggs
@dev Core contract of the game to manage Ants as ERC721 and functions to handle game operations*/

contract CryptoAnts is ERC721, ICryptoAnts, ERC721Pausable, VRFConsumerBaseV2Plus {
 
  error ReentrancyGuraded();
  error CryptoAnts_NoEggs();
  error CryptoAnts_NoZeroAddress();
  error CryptoAnts_InCorrectAmount();
  error CryptoAnts_OnwerExists();
  error CryptoAnts_CantSellDeadAnt();
  error CryptoAnts_InvalidAntOwner();
  error CryptoAnts_AntNotAlive();
  error CryptoAnts_CooldownNotComplete();
  error CryptoAnts_UnauthorizedAccess();
  error CryptoAnts_IncorrectPriceStrategy();
  error CryptoAnts_NoBalance();
  error CryptoAnts_MaxAntPriceExceeded();

  //Chainlink State Variables hardcoded for non-production environment
  uint256 public subscriptionId; //Chainlink Vrf subscription id
  bytes32 public keyHash = 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae; //key hash for vrf,previously gaslane
  uint32 private immutable _I_CALLBACKGASLIMIT = 100_000; //chainlink gas limit for callbacks
  uint16 private constant _REQUEST_CONFIRMATIONS = 3;//number of confimrations required for vrf requests
  uint32 private constant _NUM_WORDS = 2;// number of random words requested 
  address public vrfCoordinatorV2_5;//chainlink vrf cordinator

  bool public locked; //locked for reentrancy
  IEgg public immutable EGGS;//Reference to Egg contract
  uint8 private immutable _I_MAX_EGGS_PER_LAY = 20;//Maximum 
  uint256 public eggPrice =  0.01 ether;//Price of an Egg
  uint256 public antPrice = 4000000000000000;//Max Price of an Ant
  uint256 private _antIds ;//Tokenid for Ants
  uint256 public immutable I_ANTSALEDISCOUNT = 60;//antprice discount from eggprice
  uint256 private immutable _I_COOLDOWNPERIOD = 10 minutes;//M
  uint256 public deathChance = 5;//percent of Ants to die during laying eggs
  address payable public governor;

  mapping(uint256 => Ant) public ants;//Antid to Ant struct
  mapping(uint256 => uint256) public requestToAnt;//Ant to RequestId

  struct Ant {
    uint256 lastLayTime;
    bool isAlive;
  }

  event EggsBought(address indexed buyer, uint256 indexed eggsBought);
  event AntSold(uint256 indexed _antId, uint256 indexed amountsoldFor);
  event AntCreated(uint256 indexed antId, address indexed antOwner);
  event RandomnessRequested(uint256 indexed requestId);
  event AntDied(uint256 indexed antId);
  event EggsLayed(address indexed antOwner, uint256 indexed numberOfEggs);
  event PriceChanged(uint256 indexed eggPrice, uint256 indexed antPrice);

  modifier lock() {
    if (locked == true) {
      revert ReentrancyGuraded();
    }
    locked = true;
    _;
    locked = false;
  }

  constructor(
    address _eggs,
    uint256 _subscriptionId,
    address _governor,
    address _vrfCoordinatorV2_5 
  ) ERC721('Crypto Ants', 'ANTS') VRFConsumerBaseV2Plus(_vrfCoordinatorV2_5) {
    EGGS = IEgg(_eggs);
    if (_governor == address(0)) {
      revert CryptoAnts_NoZeroAddress();
    }
    subscriptionId = _subscriptionId;
    governor = payable(_governor);
    vrfCoordinatorV2_5 = _vrfCoordinatorV2_5;
  }
/*@notice Allows the users to buy specific number of eggs by paying with ether
@param _numberOfEggs The number of eggs to purchase
@dev requires the msg.value to match the total price for the eggs being bought
*/
  function buyEggs(uint256 _numberOfEggs) external payable lock {
     uint256 eggsCallerCanBuy = eggPrice * _numberOfEggs;
    if (msg.value != eggsCallerCanBuy) {
      revert CryptoAnts_InCorrectAmount();
    }
    emit EggsBought(msg.sender, eggsCallerCanBuy);
    console.log("log from cryptoants Minting eggs for:", msg.sender);
    EGGS.mint(msg.sender, _numberOfEggs); 
  
}
/*@notice Creates one new ant for the caller by utilizing one egg
@return _antId The Id of the newly created ant.
@dev Requires the caller to have atleast one egg
*/

  function createAnt() external lock returns (uint256 _antId) {
    if (EGGS.balanceOf(msg.sender) < 1) revert CryptoAnts_NoEggs();
    _antId = ++_antIds;
    ants[_antId] = Ant({lastLayTime: block.timestamp, isAlive: true});
    EGGS.burnEgg(msg.sender, 1);
    emit AntCreated(_antId, msg.sender);
    _safeMint(msg.sender, _antId);
  }
/*@notice Sells the specific Ant to the contract for its price
@param _antId Id of the ant to sell
@dev requires that msg.sender is owner of the ant & ant is alive.The bought egg is burned by the contract
*/

  function sellAnt(uint256 _antId,uint256 amount) external lock {
    if (ownerOf(_antId) != msg.sender) {
      revert CryptoAnts_InvalidAntOwner();
    }
    if (!ants[_antId].isAlive) {
      revert CryptoAnts_CantSellDeadAnt();
    }
    if(amount > antPrice)
    {
      revert CryptoAnts_MaxAntPriceExceeded();
    }
    _burn(_antId);
    emit AntSold(_antId,amount);
    (bool success,) = payable(msg.sender).call{value: amount}('');
    require(success, 'Whoops, this call failed!');
  }

/*@notice Lays a number of eggs from a specific ant, randomly after a cooldown period. Ants may die during the process.
@param _antId The id of the ant that will lay eggs
@return the id of randomness request made to chainlink vrf
@requires msg.sender to own the ant after cooldown period & ant to be alive.
*/
  function layEggs(uint256 _antId) external returns (uint256 requestId) {
    if (ownerOf(_antId) != msg.sender) {
      revert CryptoAnts_InvalidAntOwner();
    }
    if (!ants[_antId].isAlive) {
      revert CryptoAnts_AntNotAlive();
    }
    
    if (block.timestamp < ants[_antId].lastLayTime + _I_COOLDOWNPERIOD) {
      revert CryptoAnts_CooldownNotComplete();
    }
    requestId = s_vrfCoordinator.requestRandomWords(
      VRFV2PlusClient.RandomWordsRequest({
        keyHash: keyHash,
        subId: subscriptionId,
        requestConfirmations: _REQUEST_CONFIRMATIONS,
        callbackGasLimit: _I_CALLBACKGASLIMIT,
        numWords: _NUM_WORDS,
        extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
      })
    );
    ants[_antId].lastLayTime = block.timestamp;
    requestToAnt[requestId] = _antId;
    emit RandomnessRequested(requestId);
    return requestId;
    
  }
/* @notice callback function from chainlink that receives the random words for processing the egglay randomness
@param requestId the id of the randomness request from layEggs function
@param randomwords an array of random numbers returned by chainlink
@dev determines if an ant diees or survives to mint eggs based on randomwords
*/
  function fulfillRandomWords(
    uint256 requestId,
    uint256[] calldata randomWords
  ) internal override(VRFConsumerBaseV2Plus) {
    uint256 antId = requestToAnt[requestId];
    uint256 randomDieNumber = randomWords[0] % 100;
    if (randomDieNumber < deathChance) {
      ants[antId].isAlive = false;
      emit AntDied(antId);
      _burn(antId);
      return;
    }

    uint256 numberOfEggs = (randomWords[1] % (_I_MAX_EGGS_PER_LAY + 1));
    address antOwner = ownerOf(antId);
    emit EggsLayed(antOwner, numberOfEggs);
    EGGS.mint(antOwner, numberOfEggs);
  }

/*@notice sets a new price for eggs and thereby for ants
@param newPrice is the new price of eggs
@dev only callable by governor*/
  function setPrice(uint256 newPrice) external {
    if (msg.sender != governor) {
      revert CryptoAnts_UnauthorizedAccess();
    }
    if (newPrice <= 0 || newPrice < antPrice) {
      revert CryptoAnts_IncorrectPriceStrategy();
    }
    eggPrice = newPrice;
    antPrice = eggPrice * (100 - I_ANTSALEDISCOUNT) / 100;
    emit PriceChanged(eggPrice, antPrice);
  }

  function getAntPrice() external view returns (uint256) {
    return antPrice;
  }

  function isAlive(uint256 antId) external view returns (bool) {
    return ants[antId].isAlive;
  }

  function getContractBalance() public view returns (uint256) {
    return address(this).balance;
  }

  function getAntsCreated() public view returns (uint256) {
    return _antIds;
  }
/*@notice allows the governor to withdraw the balance of the contract
@dev only calleable by governor*/
  function withdraw() public {
    if (msg.sender != governor) {
      revert CryptoAnts_UnauthorizedAccess();
    }
    uint256 contractBalance = getContractBalance();
    if (getContractBalance() <= 0) {
      revert CryptoAnts_NoBalance();
    }
    // solhint-disable-next-line
    (bool success,) = msg.sender.call{value: contractBalance}('');
    require(success, 'Whoops, this call failed!');
  }

  function pause() public onlyOwner {
    _pause();
  }

  function unpause() public onlyOwner {
    _unpause();
  }

 function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721,ERC721Pausable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

   
}
