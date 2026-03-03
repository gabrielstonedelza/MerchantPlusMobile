/// Maps bank display names (as stored in CustomerAccount.bankOrNetwork)
/// to the backend AgentRequest.Bank choice keys.
const Map<String, String> bankNameToKey = {
  'Ecobank': 'ecobank',
  'GCB Bank': 'gcb',
  'Fidelity Bank': 'fidelity',
  'Cal Bank': 'cal_bank',
  'Stanbic Bank': 'stanbic',
  'Absa Bank': 'absa',
  'UBA': 'uba',
  'Access Bank': 'access',
  'Zenith Bank': 'zenith',
  'Republic Bank': 'republic',
  'Prudential Bank': 'prudential',
  'First National Bank': 'fnb',
  'Standard Chartered': 'standard_chartered',
  'Societe Generale': 'societe_generale',
  'Bank of Africa': 'boa',
  'Agricultural Dev Bank': 'adb',
  'First Atlantic Bank': 'fab',
  'OmniBSIC Bank': 'omnibsic',
  'National Investment Bank': 'nib',
  'ARB Apex Bank': 'arb_apex',
};

/// Maps mobile network display names to backend choice keys.
const Map<String, String> networkNameToKey = {
  'MTN': 'mtn',
  'Vodafone': 'vodafone',
  'AirtelTigo': 'airteltigo',
};

/// Looks up the backend key for a bank display name.
/// Falls back to lowercased name with spaces replaced by underscores.
String bankKey(String displayName) =>
    bankNameToKey[displayName] ??
    displayName.toLowerCase().replaceAll(' ', '_');

/// Looks up the backend key for a network display name.
String networkKey(String displayName) =>
    networkNameToKey[displayName] ?? displayName.toLowerCase();
