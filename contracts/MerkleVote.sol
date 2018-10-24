pragma solidity 0.4.24;


interface ERC20 {
  function totalSupply() external view returns (uint256);
  function balanceOf(address _who) external view returns (uint256);
}

import './SafeMath.sol';

// TODO: set expiry for votes
contract MerkleVote {
    using SafeMath for uint;

  // @dev methodID = bytes4(sha3("functionName(parameterType, parameterType)")
  // @dev functionID = sha3(contractAddress, methodID)
  // @dev numVotes is sha3(contractAddress, methodID, sha3(parameter, parameter)))
  // @dev quorumLevel = percentage of tokens required to be locked for the execution of a function

  ERC20 public votingToken;

  uint public securityDeposit;           // Deposit required to submit a new vote. Can be lost if merkle root is invalid


  mapping (bytes32 => bool) public voted;     // sha3(functionVoteID, msg.sender) => boolean
  mapping (bytes32 => uint) public numVotes;    // sha3(contractAddress, methodID, parameterHash)  => numberOfVotes
  mapping (bytes32 => bytes32) public merkleRoot;   //  root node of a vote merkle tree


  constructor(address _votingToken)
  public {
      votingToken = ERC20(_votingToken);
  }



  function vote(bytes32 _voteID, uint _balanceAtSnapshot, bytes32 _root, bytes32[] _proof)
  external
  returns (bool) {
    require(merkleRoot[_voteID] == _root);
    bytes32 computedElement = keccak256(abi.encodePacked(msg.sender, _balanceAtSnapshot));
    require(verifyProof(_proof, _root, computedElement));
    numVotes[_voteID] += _balanceAtSnapshot;
    return true;
  }

  function createVote(address[] _tokenHolders, bytes32 _voteID)
  public
  returns (bool) {
      bytes32[] memory elements = prepareTree(_tokenHolders);
      // bytes32 root = createRootProof(elements);
      // merkleRoot[_voteID] = root;
      return true;
  }


  // function createRootProof(bytes32[] elements)
  // public
  // pure
  // returns (bytes32) {
  //   bytes32[] memory nextElements = new bytes32[](elements.length);
  //   if (elements.length == 1) return elements[0];
  //   for (uint i = 0; i < elements.length; i+=2) {
  //     nextElements[i] = getHash(elements[i], elements[i+1]);
  //   }
  //   if (elements.length % 2 != 0){
  //     nextElements[elements.length] = keccak256(abi.encodePacked(elements[elements.length-1]));
  //   }
  //   return createRootProof(nextElements);
  // }

  function prepareTree(address[] _tokenHolders)
  public
  view
  returns (bytes32[]) {
    uint totalSupply;
    bytes32[] memory elements = new bytes32[](_tokenHolders.length);
    bytes32 leaf;
    for (uint256 i = 0; i < _tokenHolders.length; i += 2) {
      uint balanceOne = votingToken.balanceOf(_tokenHolders[i]);
      require(balanceOne > 0);   // only token holders
      uint balanceTwo = votingToken.balanceOf(_tokenHolders[i+1]);
      require(balanceTwo > 0);
      totalSupply += balanceOne + balanceTwo;
      bytes32 firstElem = keccak256(abi.encodePacked(_tokenHolders[i], balanceOne));
      bytes32 secondElem = keccak256(abi.encodePacked(_tokenHolders[i+1], balanceTwo));
      leaf = getHash(firstElem, secondElem);
      elements[i] = leaf;
    }
    if (_tokenHolders.length % 2 != 0){
      leaf = keccak256(abi.encodePacked( _tokenHolders[i], balanceOne));
      elements[_tokenHolders.length] = leaf;
    }
    // assert(totalSupply == votingToken.totalSupply());
    return elements;
  }

  /**
   * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
   * and each pair of pre-images are sorted.
   * @param _proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
   * @param _root Merkle root
   * @param _leaf Leaf of Merkle tree
   */
  function verifyProof(bytes32[] _proof, bytes32 _root, bytes32 _leaf)
  internal
  pure
  returns (bool) {
    bytes32 computedHash = _leaf;
    for (uint256 i = 0; i < _proof.length; i++) {
      bytes32 proofElement = _proof[i];
      if (computedHash < proofElement) {
        // Hash(current computed hash + current element of the proof)
        computedHash = keccak256(abi.encodePacked(computedHash, proofElement));
      } else {
        // Hash(current element of the proof + current computed hash)
        computedHash = keccak256(abi.encodePacked(proofElement, computedHash));
      }
    }
    return computedHash == _root;
  }

  function getHash(bytes32 _firstElem, bytes32 _secondElem)
  public
  pure
  returns(bytes32) {
    if (_firstElem < _secondElem){
      return keccak256(abi.encodePacked(_firstElem, _secondElem));
    }
    else{
      return keccak256(abi.encodePacked(_secondElem, _firstElem));
    }
  }


}
