// HES Appendix A seed, part 8. Run ALONE in a separate transaction: User is setup DML.
// These inactive Users cannot log in or own active service Cases.
// A license/profile restriction can reject even an inactive User insert.
User currentUser = [SELECT TimeZoneSidKey, LocaleSidKey, EmailEncodingKey, LanguageLocaleKey
    FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
Id engineerProfile = UserInfo.getProfileId();
List<Profile> standardProfiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
if (!standardProfiles.isEmpty()) engineerProfile = standardProfiles[0].Id;
String orgKey = String.valueOf(UserInfo.getOrganizationId());
Set<String> usernames = new Set<String>();
for (Integer i = 1; i <= 8; i++) {
    usernames.add('hes.seed.engineer.' + ('00' + String.valueOf(i)).right(2)
        + '.' + orgKey + '@example.invalid');
}
Set<String> present = new Set<String>();
for (User u : [SELECT Username FROM User WHERE Username IN :usernames]) present.add(u.Username);
Database.DMLOptions noMail = new Database.DMLOptions();
noMail.emailHeader.triggerUserEmail = false;
noMail.emailHeader.triggerOtherEmail = false;
List<User> engineers = new List<User>();
for (Integer i = 1; i <= 8; i++) {
    String n = ('00' + String.valueOf(i)).right(2);
    String login = 'hes.seed.engineer.' + n + '.' + orgKey + '@example.invalid';
    if (present.contains(login)) continue;
    User engineer = new User(FirstName = 'HES Demo', LastName = 'Engineer ' + n,
        Alias = 'he' + n, Username = login, Email = login,
        CommunityNickname = 'heseng' + orgKey.right(8) + n,
        IsActive = false, ProfileId = engineerProfile,
        TimeZoneSidKey = currentUser.TimeZoneSidKey,
        LocaleSidKey = currentUser.LocaleSidKey,
        EmailEncodingKey = currentUser.EmailEncodingKey,
        LanguageLocaleKey = currentUser.LanguageLocaleKey);
    engineer.setOptions(noMail);
    engineers.add(engineer);
}
if (!engineers.isEmpty()) {
    Database.SaveResult[] saved = Database.insert(engineers, false);
    for (Integer i = 0; i < saved.size(); i++) {
        if (saved[i].isSuccess()) {
            System.debug('Created inactive engineer: ' + engineers[i].Username);
        } else {
            for (Database.Error problem : saved[i].getErrors()) {
                System.debug('Engineer ' + engineers[i].Username + ' rejected: '
                    + problem.getStatusCode() + ': ' + problem.getMessage());
            }
        }
    }
}
System.debug('HES seed 08 done. Check User records; license restrictions may still prevent creation.');
