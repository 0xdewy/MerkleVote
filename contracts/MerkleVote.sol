pragma solidity 0.5.0;

interface Token {
  function totalSupply() external view returns (uint256);
  function balanceOf(address _who) external view returns (uint256);
}

import './SafeMath.sol';


contract MerkleVote {

  Token public votingToken;

  mapping (bytes32 => bool) public voted;     // sha3(functionVoteID, msg.sender) => boolean
  mapping (bytes32 => uint) public numVotes;    // voteID  => numberOfVotes
  mapping (bytes32 => bytes32) public merkleRoot;   //  root node of a vote merkle tree

  constructor(address _votingToken)
  public {
      votingToken = Token(_votingToken);
  }

  function vote(bytes32 _voteID, uint _balanceAtSnapshot, bytes32 _root, bytes32[] calldata _proof)
  external
  returns (bool) {
    require(merkleRoot[_voteID] == _root);
    require(!voted[keccak256(abi.encodePacked(_voteID, msg.sender))]);
    require(verifyProof(_proof, _root, leaf(msg.sender, _balanceAtSnapshot)));
    voted[keccak256(abi.encodePacked(_voteID, msg.sender))] = true;
    numVotes[_voteID] += _balanceAtSnapshot;
    return true;
  }

  function createVote(address[] memory _tokenHolders, bytes32 _voteID)
  public
  returns (bool) {
      require(_tokenHolders.length < 200);
      bytes32[] memory elements = hashRawData(_tokenHolders);
      bytes32 root = createTree(elements);
      merkleRoot[_voteID] = root;
      return true;
  }


  function createTree(bytes32[] memory elements)
  public
  pure
  returns (bytes32) {
    uint16 numElements = uint16(elements.length);
    if (numElements == 1) { return keccak256(abi.encodePacked(elements[0])); }
    while (numElements > 1) {
      for (uint i = 0; i < numElements; i+=2) {
        elements[i] = getHash(elements[i], elements[i+1]);
      }
      if (elements.length % 2 != 0){
        elements[(numElements / 2) + 1] = keccak256(abi.encodePacked(elements[numElements-1]));
        numElements = (numElements / 2) + 1;
      }
      else { numElements = numElements / 2; }
    }
    return elements[0];
  }

  function hashRawData(address[] memory _tokenHolders)
  public
  view
  returns (bytes32[] memory elements) {
    uint totalSupply;
    uint16 numLeafs = uint16((_tokenHolders.length / 2) + (_tokenHolders.length % 2));
    elements = new bytes32[](numLeafs);
    bytes32 node;
    uint16 counter;
    for (uint16 i = 0; i < _tokenHolders.length; i += 2) {
      uint balanceOne = votingToken.balanceOf(_tokenHolders[i]);
      require(balanceOne > 0);   // only token holders
      uint balanceTwo = votingToken.balanceOf(_tokenHolders[i+1]);
      require(balanceTwo > 0);
      totalSupply += balanceOne + balanceTwo;
      bytes32 firstLeaf = leaf(_tokenHolders[i], balanceOne);
      bytes32 secondLeaf = leaf(_tokenHolders[i+1], balanceTwo);
      node = getHash(firstLeaf, secondLeaf);
      elements[counter] = node;
      counter++;
    }
    if (_tokenHolders.length % 2 != 0){
      address thisHolder = _tokenHolders[_tokenHolders.length-1];
      node = leaf(thisHolder , votingToken.balanceOf(thisHolder));
      elements[counter] = node;
    }

    // assert(totalSupply == votingToken.totalSupply());
    return elements;
  }

  function hashLayer(bytes32[] memory elements)
  public
  pure
  returns (bytes32[] memory){
    uint16 numElementsNextLayer = uint16((elements.length / 2) + (elements.length % 2));
    bytes32[] memory layer = new bytes32[](numElementsNextLayer);
    uint16 counter;
    for (uint i = 0; i < elements.length; i+=2) {
      layer[counter] = getHash(elements[i], elements[i+1]);
      counter++;
    }
    if (elements.length % 2 != 0){
      layer[counter] = keccak256(abi.encodePacked(elements[elements.length-1]));
    }
    return layer;
  }

  /**
   * @dev Verifies a Merkle proof proving the existence of a leaf in a Merkle tree. Assumes that each pair of leaves
   * and each pair of pre-images are sorted.
   * @param _proof Merkle proof containing sibling hashes on the branch from the leaf to the root of the Merkle tree
   * @param _root Merkle root
   * @param _leaf Leaf of Merkle tree
   */
  function verifyProof(bytes32[] memory _proof, bytes32 _root, bytes32 _leaf)
  public
  pure
  returns (bool) {
    bytes32 computedHash = _leaf;
    for (uint256 i = 0; i < _proof.length; i++) {
      computedHash = getHash(computedHash, _proof[i]);
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

  function leaf(address _user, uint _balance)
  public
  pure
  returns (bytes32) {
    return keccak256(abi.encodePacked(_user, _balance));
  }


}
