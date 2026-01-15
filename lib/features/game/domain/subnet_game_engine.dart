import 'dart:math';
import 'subnet_models.dart';

class SubnetGameEngine {
  final Random _random;

  SubnetGameEngine({int? seed}) : _random = Random(seed);

  SubnetQuestion generateQuestion() {
    // 1. Private IP Generation (RFC 1918)
    final privateClass = _random.nextInt(3); // 0: A, 1: B, 2: C
    int ipInt = 0;
    int cidr = 24;

    switch (privateClass) {
      case 0: // Class A: 10.0.0.0 - 10.255.255.255
        // Fixed 10.x.x.x
        int octet2 = _random.nextInt(256);
        int octet3 = _random.nextInt(256);
        int octet4 = _random.nextInt(256);
        ipInt = (10 << 24) | (octet2 << 16) | (octet3 << 8) | octet4;
        
        // Smart Prefix: /8 to /30 (Weighted towards /16-/24)
        // Let's bias: 50% chance of /16-/24, 25% /8-/15, 25% /25-/30
        int roll = _random.nextInt(100);
        if (roll < 50) {
          cidr = 16 + _random.nextInt(9); // 16-24
        } else if (roll < 75) {
          cidr = 8 + _random.nextInt(8); // 8-15
        } else {
          cidr = 25 + _random.nextInt(6); // 25-30
        }
        break;

      case 1: // Class B: 172.16.0.0 - 172.31.255.255
        // Fixed 172.(16-31).x.x
        int octet2 = 16 + _random.nextInt(16); // 16 to 31
        int octet3 = _random.nextInt(256);
        int octet4 = _random.nextInt(256);
        ipInt = (172 << 24) | (octet2 << 16) | (octet3 << 8) | octet4;
        
        // Smart Prefix: /16 to /30
        cidr = 16 + _random.nextInt(15); // 16-30
        break;

      case 2: // Class C: 192.168.0.0 - 192.168.255.255
        // Fixed 192.168.x.x
        int octet3 = _random.nextInt(256);
        int octet4 = _random.nextInt(256);
        ipInt = (192 << 24) | (168 << 16) | (octet3 << 8) | octet4;
        
        // Smart Prefix: /24 to /30
        cidr = 24 + _random.nextInt(7); // 24-30
        break;
    }

    // 2. Calculate Core Attributes
    // Mask
    // In Dart, shifting 32 bits might differ on web/native due to JS numbers, but mostly fine for standard int.
    // Safe mask generation:
    int mask = (0xFFFFFFFF << (32 - cidr)) & 0xFFFFFFFF;
    
    // Network Address
    int networkInt = ipInt & mask;
    
    // Broadcast Address
    int broadcastInt = networkInt | (~mask & 0xFFFFFFFF);
    
    // First Usable Host (Network + 1)
    int firstUsableInt = networkInt + 1;
    
    // Last Usable Host (Broadcast - 1)
    int lastUsableInt = broadcastInt - 1;
    
    // Next Subnet Network (Broadcast + 1)
    int nextSubnetNetInt = broadcastInt + 1;
    int nextSubnetBroadcastInt = nextSubnetNetInt | (~mask & 0xFFFFFFFF); // Theoretical
    
    // Previous Subnet Network (Network - SubnetSize)
    // Subnet Size = 2^(32-cidr)
    // Or simpler: Network - 1 is the broadcast of previous. 
    int prevSubnetBroadcastInt = networkInt - 1;
    int prevSubnetNetInt = prevSubnetBroadcastInt & mask; // Clean it to find start

    // 3. Question Type Selection
    // Pick a random type. Since we use a seeded random, both players get same type
    final typeIndex = _random.nextInt(QuestionType.values.length);
    final questionType = QuestionType.values[typeIndex];

    int correctAnswerInt;
    switch (questionType) {
      case QuestionType.broadcast:
        correctAnswerInt = broadcastInt;
        break;
      case QuestionType.firstUsable:
        correctAnswerInt = firstUsableInt;
        break;
      case QuestionType.lastUsable:
        correctAnswerInt = lastUsableInt;
        break;
      case QuestionType.network:
      default:
        correctAnswerInt = networkInt;
        break;
    }

    String correctAnswer = IPUtils.intToIp(correctAnswerInt);
    
    // 4. The 'Distractor Pool'
    // Smart Distractors: Include the other critical addresses (Net, Broad, First, Last) as wrong options
    
    Set<int> distractorInts = {};
    
    // Always tempt with these critical boundaries
    distractorInts.add(networkInt);
    distractorInts.add(broadcastInt);
    distractorInts.add(firstUsableInt);
    distractorInts.add(lastUsableInt);
    
    // Validity Check & Next/Prev Subnet Distractors
    if (nextSubnetNetInt <= 0xFFFFFFFF) {
      distractorInts.add(nextSubnetNetInt);
      distractorInts.add(nextSubnetBroadcastInt);
    }
    
    if (prevSubnetNetInt >= 0) {
      distractorInts.add(prevSubnetNetInt);
      distractorInts.add(prevSubnetBroadcastInt);
    }
    
    // Convert to Strings and Filter
    Set<String> optionsSet = {};
    optionsSet.add(correctAnswer); // Ensure correct answer is tracked
    
    // Shuffle the pool for randomness
    List<int> poolList = distractorInts.toList()..shuffle(_random);
    
    // Pick 3 UNIQUE distractors
    for (int dVal in poolList) {
      if (optionsSet.length >= 4) break; // 1 Correct + 3 Wrong = 4
      
      String dStr = IPUtils.intToIp(dVal);
      
      // Don't add if it's the correct answer
      if (dStr != correctAnswer) {
        optionsSet.add(dStr);
      }
    }
    
    // Fallback: If we don't have enough options (rare /32 edge cases), generate random offsets
    while (optionsSet.length < 4) {
      // Create a random fake IP close to the correct answer
      int fakeOffset = _random.nextInt(10) + 1;
      int fakeInt = correctAnswerInt + (folderSign() * fakeOffset);
       // ensure positive
       if (fakeInt < 0) fakeInt = fakeInt.abs();
       optionsSet.add(IPUtils.intToIp(fakeInt));
    }
    
    List<String> finalOptions = optionsSet.toList()..shuffle(_random);

    return SubnetQuestion(
      ipAddress: IPUtils.intToIp(ipInt),
      cidr: cidr,
      correctAnswer: correctAnswer,
      options: finalOptions,
      type: questionType,
    );
  }
  
  int folderSign() => _random.nextBool() ? 1 : -1;
}
