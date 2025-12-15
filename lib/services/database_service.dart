import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'package:flutter/foundation.dart';

class DatabaseService {
  final String? uid;
  DatabaseService({this.uid});

  // Collection reference
  final CollectionReference userCollection = FirebaseFirestore.instance
      .collection('users');
  final CollectionReference messCollection = FirebaseFirestore.instance
      .collection('messes');

  Future<void> saveUserData(
    String name,
    String email,
    String phone,
    String role,
  ) async {
    return await userCollection.doc(uid).set({
      'name': name,
      'email': email,
      'phone': phone,
      'role': role,
    });
  }

  // Get user document from Firestore
  Future<DocumentSnapshot> getUserData() async {
    return await userCollection.doc(uid).get();
  }

  // Create a new mess for a manager
  Future<String> createMess(
    String messName,
    String createdMonth,
    String managerName,
  ) async {
    // Generate a simple random invite code
    String inviteCode = (Random().nextInt(900000) + 100000).toString();

    DocumentReference messDocRef = await messCollection.add({
      'messName': messName,
      'managerId': uid,
      'managerName': managerName,
      'createdMonth': createdMonth,
      'inviteCode': inviteCode,
      'members': [uid], // Manager is also a member
      'currentSessionDate': Timestamp.fromDate(
        DateTime(DateTime.now().year, DateTime.now().month, 1),
      ),
    });

    // Update the user's document with the messId
    await userCollection.doc(uid).update({'messId': messDocRef.id});

    return messDocRef.id;
  }

  // Get mess data by messId
  Future<DocumentSnapshot> getMessData(String messId) async {
    return await messCollection.doc(messId).get();
  }

  // Join a mess with an invite code
  Future<Map<String, dynamic>?> joinMessWithCode(String inviteCode) async {
    // Find the mess with the given invite code
    QuerySnapshot messQuery = await messCollection
        .where('inviteCode', isEqualTo: inviteCode)
        .limit(1)
        .get();

    if (messQuery.docs.isNotEmpty) {
      DocumentSnapshot messDoc = messQuery.docs.first;
      String messId = messDoc.id;

      // Add the member's UID to the mess's members list
      await messCollection.doc(messId).update({
        'members': FieldValue.arrayUnion([uid]),
      });

      // Update the user's document with the messId
      await userCollection.doc(uid).update({'messId': messId});

      // Notify all members that a new member joined
      try {
        // Get joining user's name
        var joiningUserDoc = await userCollection.doc(uid).get();
        var joiningUserData = joiningUserDoc.data() as Map<String, dynamic>?;
        String joiningName =
            (joiningUserData != null && joiningUserData['name'] != null)
            ? joiningUserData['name'] as String
            : 'A new member';

        var messData = messDoc.data() as Map<String, dynamic>;
        String messName = messData['messName'] ?? 'the mess';

        await sendNotificationToMembers(
          messId,
          'New Member Joined',
          '$joiningName joined $messName.',
          'member_join',
        );
      } catch (e) {
        debugPrint('Error notifying about new member: $e');
      }

      var data = messDoc.data() as Map<String, dynamic>;
      data['id'] = messId; // Add messId to the returned map
      return data;
    }
    return null; // Return null if no mess is found
  }

  // Get invite code for a mess
  Future<String?> getInviteCode(String messId) async {
    try {
      DocumentSnapshot messDoc = await messCollection.doc(messId).get();
      return (messDoc.data() as Map<String, dynamic>)['inviteCode'];
    } catch (e) {
      debugPrint(e.toString());
      return null;
    }
  }

  // Get all members of a mess
  Future<List<DocumentSnapshot>> getMessMembers(String messId) async {
    try {
      DocumentSnapshot messDoc = await messCollection.doc(messId).get();
      List<String> memberUids = List<String>.from(
        (messDoc.data() as Map<String, dynamic>)['members'] ?? [],
      );

      if (memberUids.isEmpty) {
        return [];
      }

      QuerySnapshot membersQuery = await userCollection
          .where(FieldPath.documentId, whereIn: memberUids)
          .get();
      return membersQuery.docs;
    } catch (e) {
      debugPrint(e.toString());
      return [];
    }
  }

  // Add a deposit for a member
  Future<void> addDeposit(
    String messId,
    String memberUid,
    String memberName,
    double amount,
    String managerName,
  ) async {
    try {
      final depositData = {
        'memberUid': memberUid,
        'memberName': memberName,
        'amount': amount,
        'date': Timestamp.now(),
        'addedBy': managerName,
      };

      // Add to deposits subcollection for history
      await userCollection
          .doc(memberUid)
          .collection('deposits')
          .add(depositData);

      // Also add to the mess's deposits subcollection for monthly records
      await messCollection.doc(messId).collection('deposits').add(depositData);

      // Update the total deposit amount for the member
      await userCollection.doc(memberUid).update({
        'totalDeposit': FieldValue.increment(amount),
      });
      // Notify all members about the deposit
      await sendNotificationToMembers(
        messId,
        'Deposit Added',
        '$managerName added ৳${amount.toStringAsFixed(2)} to $memberName\'s account.',
        'deposit',
      );

      // Check balance and notify if low
      DateTime now = DateTime.now();
      double totalDeposit = await getTotalMessDeposit(messId);
      double totalCost = await getTotalMessCostForMonth(messId, now);
      double balance = totalDeposit - totalCost;
      if (balance < 500) {
        await sendNotificationToMembers(
          messId,
          'Low Balance Alert',
          'Mess balance is low: ৳${balance.toStringAsFixed(2)}. Please take action.',
          'balance_alert',
        );
      }
    } catch (e) {
      debugPrint(e.toString());
    }
  }

  // Create a notification document in mess notifications subcollection
  Future<void> createNotification(
    String messId,
    String title,
    String body,
    String type, {
    required List<String> unreadFor,
  }) async {
    try {
      await messCollection.doc(messId).collection('notifications').add({
        'title': title,
        'body': body,
        'type': type,
        'createdAt': Timestamp.now(),
        'unreadFor': unreadFor,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  // Send notification to all members of the mess
  Future<void> sendNotificationToMembers(
    String messId,
    String title,
    String body,
    String type,
  ) async {
    try {
      DocumentSnapshot messDoc = await messCollection.doc(messId).get();
      var data = messDoc.data() as Map<String, dynamic>;
      List<dynamic> members = data['members'] ?? [];
      List<String> memberUids = members.map((e) => e.toString()).toList();
      if (memberUids.isNotEmpty) {
        await createNotification(
          messId,
          title,
          body,
          type,
          unreadFor: memberUids,
        );
      }
    } catch (e) {
      debugPrint('Error sending notification to members: $e');
    }
  }

  // Send notification to manager only
  Future<void> sendNotificationToManager(
    String messId,
    String title,
    String body,
    String type,
  ) async {
    try {
      DocumentSnapshot messDoc = await messCollection.doc(messId).get();
      var data = messDoc.data() as Map<String, dynamic>;
      String? managerId = data['managerId'];
      if (managerId != null && managerId.isNotEmpty) {
        await createNotification(
          messId,
          title,
          body,
          type,
          unreadFor: [managerId],
        );
      }
    } catch (e) {
      debugPrint('Error sending notification to manager: $e');
    }
  }

  // Stream unread notifications count for a user in a mess
  Stream<int> unreadNotificationCountStream(String messId, String uid) {
    return messCollection
        .doc(messId)
        .collection('notifications')
        .where('unreadFor', arrayContains: uid)
        .snapshots()
        .map((s) => s.docs.length);
  }

  // Stream all notifications for a mess
  Stream<QuerySnapshot> notificationsStream(String messId) {
    return messCollection
        .doc(messId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // Mark a notification as read for a user (remove uid from unreadFor)
  Future<void> markNotificationRead(
    String messId,
    String notificationId,
    String uid,
  ) async {
    try {
      await messCollection
          .doc(messId)
          .collection('notifications')
          .doc(notificationId)
          .update({
            'unreadFor': FieldValue.arrayRemove([uid]),
          });
    } catch (e) {
      debugPrint('Error marking notification read: $e');
    }
  }

  // Mark all notifications as read for a user
  Future<void> markAllNotificationsRead(String messId, String uid) async {
    try {
      QuerySnapshot qs = await messCollection
          .doc(messId)
          .collection('notifications')
          .where('unreadFor', arrayContains: uid)
          .get();
      if (qs.docs.isEmpty) return;
      WriteBatch batch = FirebaseFirestore.instance.batch();
      for (var doc in qs.docs) {
        batch.update(doc.reference, {
          'unreadFor': FieldValue.arrayRemove([uid]),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  // Remove a member from a mess and clear their messId
  // Returns true if the operation succeeded
  Future<bool> removeMemberFromMess(String messId, String memberUid) async {
    try {
      // Remove member UID from the mess document
      await messCollection.doc(messId).update({
        'members': FieldValue.arrayRemove([memberUid]),
      });

      // Clear the messId on the user's document
      await userCollection.doc(memberUid).update({'messId': null});

      return true;
    } catch (e) {
      debugPrint('removeMemberFromMess error: ${e.toString()}');
      return false;
    }
  }

  // Get daily meals for a mess
  Future<DocumentSnapshot> getDailyMeals(String messId, String date) async {
    return await messCollection.doc(messId).collection('meals').doc(date).get();
  }

  // Update meal count for a member
  Future<void> updateMealCount(
    String messId,
    String date,
    String memberUid,
    int newMealCount,
  ) async {
    try {
      // Path to the daily meal document
      DocumentReference dailyMealDocRef = messCollection
          .doc(messId)
          .collection('meals')
          .doc(date);

      // Use a transaction to handle the case where the document might not exist
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // We don't need to read the doc first for this operation
        transaction.set(
          dailyMealDocRef,
          {
            'memberMeals': {memberUid: newMealCount},
          },
          SetOptions(
            merge: true,
          ), // Merge to avoid overwriting other members' meals
        );
      });
    } catch (e) {
      debugPrint('Error updating meal count: $e');
    }
  }

  // Add to an existing meal count for a member on a specific date
  Future<void> addMeal({
    required String messId,
    required String date,
    required String memberUid,
    required int mealsToAdd,
  }) async {
    DocumentReference dailyMealDocRef = messCollection
        .doc(messId)
        .collection('meals')
        .doc(date);

    // Use a transaction to handle race conditions
    return FirebaseFirestore.instance
        .runTransaction((transaction) async {
          DocumentSnapshot snapshot = await transaction.get(dailyMealDocRef);

          if (!snapshot.exists) {
            // If the document for the day doesn't exist, create it with the new meal count.
            transaction.set(dailyMealDocRef, {
              'memberMeals': {memberUid: mealsToAdd},
            });
          } else {
            // If the document exists, increment the meal count for the member.
            // Using dot notation with FieldValue.increment is the most robust way.
            transaction.update(dailyMealDocRef, {
              'memberMeals.$memberUid': FieldValue.increment(mealsToAdd),
            });
          }
        })
        .catchError((error) {
          debugPrint("Failed to add meal: $error");
          // Optionally rethrow or handle the error as needed
        });
  }

  // Batch update meal counts for multiple members
  Future<void> batchUpdateMealCounts(
    String messId,
    String date,
    Map<String, int> mealCounts,
  ) async {
    try {
      DocumentReference dailyMealDocRef = messCollection
          .doc(messId)
          .collection('meals')
          .doc(date);

      // Prepare the data to be merged.
      // This will update or add meals for the members in the map.
      Map<String, dynamic> dataToMerge = {'memberMeals': mealCounts};

      // Set with merge option to update the document without overwriting existing fields.
      await dailyMealDocRef.set(dataToMerge, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error batch updating meal counts: $e');
    }
  }

  // Get total meals for the current month for a mess
  Future<int> getTotalMessMealsForMonth(String messId, DateTime date) async {
    try {
      String monthPrefix =
          "${date.year}-${date.month.toString().padLeft(2, '0')}";

      // Query the 'meals' subcollection for documents matching the current month
      QuerySnapshot dailyMealsSnapshot = await messCollection
          .doc(messId)
          .collection('meals')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: monthPrefix)
          .where(FieldPath.documentId, isLessThan: '$monthPrefix\uf8ff')
          .get();

      int totalMeals = 0;

      // Iterate through each day's meal document and sum up the meals
      for (var doc in dailyMealsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('memberMeals')) {
          var memberMeals = data['memberMeals'] as Map<String, dynamic>;
          for (var count in memberMeals.values) {
            totalMeals += (count as num).toInt();
          }
        }
      }
      return totalMeals;
    } catch (e) {
      debugPrint('Error getting total mess meals: $e');
      return 0;
    }
  }

  // Get total meals for a specific member for the current month
  Future<int> getMemberTotalMealsForMonth(
    String messId,
    String memberUid,
    DateTime date,
  ) async {
    try {
      String monthPrefix =
          "${date.year}-${date.month.toString().padLeft(2, '0')}";

      // Query the 'meals' subcollection for documents matching the current month
      QuerySnapshot dailyMealsSnapshot = await messCollection
          .doc(messId)
          .collection('meals')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: monthPrefix)
          .where(FieldPath.documentId, isLessThan: '$monthPrefix\uf8ff')
          .get();

      int totalMeals = 0;

      // Iterate through each day's meal document and sum up the meals for the specific member
      for (var doc in dailyMealsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('memberMeals')) {
          var memberMeals = data['memberMeals'] as Map<String, dynamic>;
          if (memberMeals.containsKey(memberUid)) {
            totalMeals += (memberMeals[memberUid] as num).toInt();
          }
        }
      }
      return totalMeals;
    } catch (e) {
      debugPrint('Error getting member total meals: $e');
      return 0;
    }
  }

  // Get meal history for a specific member for the current month (date -> meal count)
  Future<Map<String, int>> getMemberMealHistoryForMonth(
    String messId,
    String memberUid,
    DateTime date,
  ) async {
    try {
      String monthPrefix =
          "${date.year}-${date.month.toString().padLeft(2, '0')}";

      // Query the 'meals' subcollection for documents matching the current month
      QuerySnapshot dailyMealsSnapshot = await messCollection
          .doc(messId)
          .collection('meals')
          .where(FieldPath.documentId, isGreaterThanOrEqualTo: monthPrefix)
          .where(FieldPath.documentId, isLessThan: '$monthPrefix\uf8ff')
          .get();

      Map<String, int> mealHistory = {};

      // Iterate through each day's meal document and get the meal count for the specific member
      for (var doc in dailyMealsSnapshot.docs) {
        var data = doc.data() as Map<String, dynamic>?;
        var memberMeals = data?['memberMeals'] as Map<String, dynamic>?;
        if (memberMeals != null && memberMeals.containsKey(memberUid)) {
          mealHistory[doc.id] = (memberMeals[memberUid] as num).toInt();
        }
      }
      return mealHistory;
    } catch (e) {
      debugPrint('Error getting member meal history: $e');
      return {};
    }
  }

  // Add a mess cost/bazar
  Future<void> addMessCost({
    required String messId,
    required String memberUid,
    required String memberName,
    required String details,
    required double amount,
    required String managerUid,
    required String managerName,
  }) async {
    try {
      await messCollection.doc(messId).collection('costs').add({
        'memberUid': memberUid,
        'memberName': memberName,
        'details': details,
        'amount': amount,
        'date': Timestamp.now(),
        'addedByManagerUid': managerUid,
        'addedByManagerName': managerName,
      });
      // Notify members about the new cost
      await sendNotificationToMembers(
        messId,
        'New Cost Added',
        '$managerName added a cost: $details (৳${amount.toStringAsFixed(2)}).',
        'cost',
      );

      // Check balance and notify if low
      DateTime now = DateTime.now();
      double totalDeposit = await getTotalMessDeposit(messId);
      double totalCost = await getTotalMessCostForMonth(messId, now);
      double balance = totalDeposit - totalCost;
      if (balance < 500) {
        await sendNotificationToMembers(
          messId,
          'Low Balance Alert',
          'Mess balance is low: ৳${balance.toStringAsFixed(2)}. Please take action.',
          'balance_alert',
        );
      }
    } catch (e) {
      debugPrint('Error adding mess cost: $e');
    }
  }

  // Get all costs for the current month for a mess
  Future<List<DocumentSnapshot>> getMessCostsForMonth(
    String messId,
    DateTime date,
  ) async {
    try {
      // Calculate the start and end of the current month
      DateTime startOfMonth = DateTime(date.year, date.month, 1);
      DateTime endOfMonth = (date.month < 12)
          ? DateTime(date.year, date.month + 1, 1)
          : DateTime(date.year + 1, 1, 1);

      Timestamp startTimestamp = Timestamp.fromDate(startOfMonth);
      Timestamp endTimestamp = Timestamp.fromDate(endOfMonth);

      // Query the 'costs' subcollection for documents within the current month
      QuerySnapshot costsSnapshot = await messCollection
          .doc(messId)
          .collection('costs')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThan: endTimestamp)
          .orderBy('date', descending: true) // Show most recent first
          .get();

      return costsSnapshot.docs;
    } catch (e) {
      debugPrint('Error getting mess costs: $e');
      return [];
    }
  }

  // Get total cost amount for the current month
  Future<double> getTotalMessCostForMonth(String messId, DateTime date) async {
    try {
      List<DocumentSnapshot> costs = await getMessCostsForMonth(messId, date);
      double totalCost = 0.0;
      for (var doc in costs) {
        totalCost += (doc['amount'] as num).toDouble();
      }
      return totalCost;
    } catch (e) {
      debugPrint('Error getting total mess cost: $e');
      return 0.0;
    }
  }

  // Get total deposit for all members in a mess
  Future<double> getTotalMessDeposit(String messId) async {
    try {
      List<DocumentSnapshot> members = await getMessMembers(messId);
      double totalDeposit = 0.0;
      for (var memberDoc in members) {
        var memberData = memberDoc.data() as Map<String, dynamic>;
        totalDeposit += (memberData['totalDeposit'] ?? 0.0).toDouble();
      }
      return totalDeposit;
    } catch (e) {
      debugPrint('Error getting total mess deposit: $e');
      return 0.0;
    }
  }

  // Get all deposits for the current month for a mess
  Future<List<DocumentSnapshot>> getMessDepositsForMonth(
    String messId,
    DateTime date,
  ) async {
    try {
      // Calculate the start and end of the current month
      DateTime startOfMonth = DateTime(date.year, date.month, 1);
      DateTime endOfMonth = (date.month < 12)
          ? DateTime(date.year, date.month + 1, 1)
          : DateTime(date.year + 1, 1, 1);

      Timestamp startTimestamp = Timestamp.fromDate(startOfMonth);
      Timestamp endTimestamp = Timestamp.fromDate(endOfMonth);

      // Query the 'deposits' subcollection for documents within the current month
      QuerySnapshot depositsSnapshot = await messCollection
          .doc(messId)
          .collection('deposits')
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThan: endTimestamp)
          .orderBy('date', descending: true)
          .get();
      return depositsSnapshot.docs;
    } catch (e) {
      debugPrint('Error getting mess deposits for month: $e');
      return [];
    }
  }

  // Get deposit history for a specific member
  Future<List<DocumentSnapshot>> getMemberDepositHistory(
    String memberUid,
  ) async {
    try {
      QuerySnapshot depositSnapshot = await userCollection
          .doc(memberUid)
          .collection('deposits')
          .orderBy('date', descending: true)
          .get();
      return depositSnapshot.docs;
    } catch (e) {
      debugPrint('Error getting member deposit history: $e');
      return [];
    }
  }

  // Update mess name
  Future<bool> updateMessName(String messId, String newName) async {
    try {
      // Capture old name to mention in notification
      var doc = await messCollection.doc(messId).get();
      var oldName =
          (doc.data() as Map<String, dynamic>?)?['messName'] ?? 'the mess';
      await messCollection.doc(messId).update({'messName': newName});

      // Notify all members about the name change
      try {
        await sendNotificationToMembers(
          messId,
          'Mess Name Updated',
          'Mess name changed from "$oldName" to "$newName".',
          'mess_rename',
        );
      } catch (e) {
        debugPrint('Error notifying about mess name change: $e');
      }
      return true;
    } catch (e) {
      debugPrint('Error updating mess name: $e');
      return false;
    }
  }

  // Submit or update a meal request for a member
  Future<void> submitMealRequest({
    required String messId,
    required String memberUid,
    required String memberName,
    required String requestForDate, // YYYY-MM-DD
    required Map<String, dynamic>
    meals, // {'morning': {'on': bool, 'extra': int}, ...}
  }) async {
    try {
      // A unique ID for the request document based on member and date
      final docId = '${requestForDate}_$memberUid';

      await messCollection
          .doc(messId)
          .collection('mealRequests')
          .doc(docId)
          .set({
            'memberUid': memberUid,
            'memberName': memberName,
            'requestForDate': requestForDate,
            'meals': meals,
            'timestamp': FieldValue.serverTimestamp(),
          });
      // Notify manager about the meal request
      await sendNotificationToManager(
        messId,
        'Meal Request',
        '$memberName submitted a meal request for $requestForDate.',
        'meal_request',
      );
    } catch (e) {
      debugPrint('Error submitting meal request: $e');
    }
  }

  // Get all meal requests for a specific date
  Future<List<DocumentSnapshot>> getMealRequestsForDate(
    String messId,
    String date, // YYYY-MM-DD
  ) async {
    try {
      QuerySnapshot requestSnapshot = await messCollection
          .doc(messId)
          .collection('mealRequests')
          .where('requestForDate', isEqualTo: date)
          .get();
      return requestSnapshot.docs;
    } catch (e) {
      debugPrint('Error getting meal requests: $e');
      return [];
    }
  }

  // Change manager of a mess
  Future<bool> changeManager({
    required String messId,
    required String currentManagerUid,
    required String newManagerUid,
    required String newManagerName,
  }) async {
    try {
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // 1. Update Mess Document
        DocumentReference messRef = messCollection.doc(messId);
        transaction.update(messRef, {
          'managerId': newManagerUid,
          'managerName': newManagerName,
        });

        // 2. Update Old Manager (Current User) to Member
        DocumentReference oldManagerRef = userCollection.doc(currentManagerUid);
        transaction.update(oldManagerRef, {'role': 'member'});

        // 3. Update New Manager (Selected Member) to Manager
        DocumentReference newManagerRef = userCollection.doc(newManagerUid);
        transaction.update(newManagerRef, {'role': 'manager'});
      });
      return true;
    } catch (e) {
      debugPrint('Error changing manager: $e');
      return false;
    }
  }

  // Archive month and start new
  Future<bool> startNewMonth(String messId, DateTime currentMonthDate) async {
    try {
      // 1. Calculate current month's report to archive
      final totalCost = await getTotalMessCostForMonth(
        messId,
        currentMonthDate,
      );
      final totalMeals = await getTotalMessMealsForMonth(
        messId,
        currentMonthDate,
      );
      final members = await getMessMembers(messId);

      double mealRate = (totalMeals > 0) ? totalCost / totalMeals : 0.0;

      List<Map<String, dynamic>> memberReports = [];
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var memberDoc in members) {
        final memberUid = memberDoc.id;
        final memberData = memberDoc.data() as Map<String, dynamic>;
        final myMeals = await getMemberTotalMealsForMonth(
          messId,
          memberUid,
          currentMonthDate,
        );
        final myDeposit = (memberData['totalDeposit'] ?? 0.0).toDouble();
        final myCost = myMeals * mealRate;
        final myBalance = myDeposit - myCost;

        memberReports.add({
          'uid': memberUid,
          'name': memberData['name'],
          'meals': myMeals,
          'cost': myCost,
          'deposit': myDeposit,
          'balance': myBalance,
        });

        // Update member's totalDeposit to the remaining balance (carry over)
        // This effectively "resets" the month for the user
        batch.update(userCollection.doc(memberUid), {
          'totalDeposit': myBalance,
        });
      }

      // 3. Update mess current session to next month
      DateTime nextMonth = DateTime(
        currentMonthDate.year,
        currentMonthDate.month + 1,
        1,
      );
      batch.update(messCollection.doc(messId), {
        'currentSessionDate': Timestamp.fromDate(nextMonth),
      });

      // 2. Save archived report
      String monthKey =
          "${currentMonthDate.year}-${currentMonthDate.month.toString().padLeft(2, '0')}";
      DocumentReference reportRef = messCollection
          .doc(messId)
          .collection('monthly_reports')
          .doc(monthKey);

      batch.set(reportRef, {
        'month': monthKey,
        'totalCost': totalCost,
        'totalMeals': totalMeals,
        'mealRate': mealRate,
        'memberReports': memberReports,
        'archivedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint("Error starting new month: $e");
      return false;
    }
  }

  // Get archived report for a specific month
  Future<DocumentSnapshot> getArchivedReport(
    String messId,
    DateTime date,
  ) async {
    String monthKey = "${date.year}-${date.month.toString().padLeft(2, '0')}";
    return await messCollection
        .doc(messId)
        .collection('monthly_reports')
        .doc(monthKey)
        .get();
  }

  // Delete mess and all related data
  Future<bool> deleteMess(String messId) async {
    try {
      // 1. Get mess document to find members
      DocumentSnapshot messDoc = await messCollection.doc(messId).get();
      if (!messDoc.exists) return false;

      List<dynamic> members =
          (messDoc.data() as Map<String, dynamic>)['members'] ?? [];

      // 2. Delete subcollections documents
      List<String> collections = [
        'meals',
        'deposits',
        'costs',
        'mealRequests',
        'monthly_reports',
      ];

      for (String collectionName in collections) {
        var snapshot = await messCollection
            .doc(messId)
            .collection(collectionName)
            .get();
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      }

      // 3. Update users and delete mess doc in a batch
      WriteBatch batch = FirebaseFirestore.instance.batch();

      for (var memberUid in members) {
        if (memberUid is String) {
          batch.update(userCollection.doc(memberUid), {
            'messId': FieldValue.delete(),
          });
        }
      }

      batch.delete(messCollection.doc(messId));

      await batch.commit();
      return true;
    } catch (e) {
      debugPrint('Error deleting mess: $e');
      return false;
    }
  }

  // Update user profile
  Future<bool> updateUserProfile(
    String uid,
    String name,
    String email,
    String phone,
  ) async {
    try {
      await userCollection.doc(uid).update({
        'name': name,
        'email': email,
        'phone': phone,
      });
      return true;
    } catch (e) {
      debugPrint('Error updating user profile: $e');
      return false;
    }
  }
}
