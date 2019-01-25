pragma solidity >=0.5.0 <0.6.0;

interface Token {
  function totalSupply() external view returns (uint256);
  function balanceOf(address _who) external view returns (uint256);
}

import './SafeMath.sol';


contract MerkleVote {

  struct Vote {
      address token;
      uint256 yesVotes;
      uint256 noVotes;
      bytes32 root;
      mapping (address => bool) voted;
  }

  mapping (bytes32 => Vote) public votes;


  // constructor()
  // public {
  // }

  function vote(bytes32 _voteID, bool _voteYes, uint256 _balanceAtSnapshot, bytes32 _root, bytes32[] calldata _proof)
  external
  returns (bool) {
    Vote storage thisVote = votes[_voteID];
    require(thisVote.root == _root);
    require(!thisVote.voted[msg.sender]);
    require(verifyProof(_proof, _root, leaf(msg.sender, _balanceAtSnapshot)));
    thisVote.voted[msg.sender] = true;
    if (_voteYes) { thisVote.yesVotes += _balanceAtSnapshot; }
    else { thisVote.noVotes += _balanceAtSnapshot; }
    return true;
  }

  function createVote(address _token, address[] memory _tokenHolders, bytes32 _voteID)
  public
  returns (bool) {
      require(_tokenHolders.length < 200);
      Vote storage newVote = votes[_voteID];
      require(newVote.token == address(0));
      newVote.token = _token;
      bytes32[] memory elements = hashRawData(_token, _tokenHolders);
      bytes32 root = createTree(elements);
      newVote.root = root;
      return true;
  }


  function createTree(bytes32[] memory elements)
  public
  pure
  returns (bytes32) {
    uint16 numElements = uint16(elements.length);
    if (numElements == 1) { return getHash(elements[0], elements[0]); }  // Hash element with itself
    while (numElements > 1) {
      // uint16 counter;   // counter represents number of elements in each layer as tree gets constructed
      // for (uint i = 0; i < numElements; i+=2) {
      //   elements[counter] = getHash(elements[i], elements[i+1]);
      //   counter++;
      // }
      elements = hashLayer(elements);
      numElements = (numElements / 2) + (numElements % 2);
      // if (numElements % 2 != 0){        // If odd number of elements, the last element gets hashed with itself
      //   elements[counter] = getHash(elements[numElements-1], elements[numElements-1]);
      //   numElements = (numElements / 2) + 1;
      // }
      // else { numElements = numElements / 2; }
    }
    return elements[0];
  }

  function hashLayer(bytes32[] memory elements)
  public
  pure
  returns (bytes32[] memory){
    require(elements.length > 1);
    bytes32[] memory layer = new bytes32[]((elements.length / 2) + (elements.length % 2));
    if (elements.length == 2) {
        layer[0] = getHash(elements[0], elements[1]);
        return layer;
    }
    uint16 counter;
    for (uint i = 0; i < elements.length; i+=2) {
      layer[counter] = getHash(elements[i], elements[i+1]);
      counter++;
    }
    if (elements.length % 2 != 0){    // If odd number of elements, hash the last element with itself
      layer[counter] = getHash(elements[elements.length-1], elements[elements.length-1]);
    }
    return layer;
  }

  function hashRawData(address _token, address[] memory _tokenHolders)
  public
  view
  returns (bytes32[] memory elements) {
    elements = new bytes32[](_tokenHolders.length);
    uint256 balance;
    uint256 totalSupply;
    for (uint16 i = 0; i < _tokenHolders.length; i++) {
      balance = Token(_token).balanceOf(_tokenHolders[i]);
      require(balance > 0);   // only users with tokens can participate
      totalSupply += balance;
      elements[i] = leaf(_tokenHolders[i], balance);
    }
    assert(totalSupply == Token(_token).totalSupply());
    return elements;
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
