/// Things you fill in once. See SETUP-GUIDE.md, steps 3 and 6.
class Config {
  /// Your own sync server: the address of the taskora-api folder you uploaded
  /// to your hosting (must be https). See SETUP-GUIDE.md, Part 2.
  static const apiBase = 'https://rabbyhossain.com/taskora-api';

  /// Your GitHub user name and the repository that holds this code.
  /// The app looks at this repo's latest Release to find updates.
  static const githubOwner = 'rabbyhossain2927';
  static const githubRepo = 'taskora';

  /// Firebase console > Authentication > Sign-in method > Google >
  /// "Web SDK configuration" > Web client ID. Ends with .apps.googleusercontent.com
  static const googleWebClientId = '305454392450-7pqo18kuvg073vs05fq3aep1j8tp7h5s.apps.googleusercontent.com';

  static const appName = 'TaskOra';
  static const supportEmail = 'support@rabbyhossain.com';
  static const website = 'https://rabbyhossain.com';
}
void broken() { int x = 'oops'; }
