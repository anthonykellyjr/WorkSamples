@isTest
public class TestFactoryDefaults{

  // To specify defaults for objects, use the naming convention [ObjectName]Defaults.
  // For custom objects, omit the __c from the Object Name

  public class UserDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      String lastName = 'Tester';
      Integer uniqueInteger = System.now().millisecond();
      return new Map<Schema.SObjectField, Object> {
        User.FirstName         => 'Inigo Montoya',
        User.LastName          => lastName,
        User.Alias             => EncodingUtil.convertToHex(Crypto.generateDigest('SHA1', Blob.valueOf(lastName + uniqueInteger))).substring(0,8),
        User.Email             => lastName + '.' + uniqueInteger + '.' + UserInfo.getOrganizationId() + '@example.com',
        User.Username          => lastName + '.' + uniqueInteger + '@example.com.' + UserInfo.getOrganizationId(),
        User.ProfileId         => [SELECT Id FROM Profile WHERE Name  = 'System Administrator' LIMIT 1].Id,
        // User.UserRoleId     => [SELECT Id FROM UserRole WHERE Name = 'CEO' LIMIT 1].Id,
        User.TimeZoneSidKey    => 'America/Chicago',
        User.LanguageLocaleKey => 'en_US',
        User.EmailEncodingKey  => 'UTF-8',
        User.LocaleSidKey      => 'en_US'
      };
    }
  }

  public class AccountDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
        Account.Name => 'Test Account'
      };
    }
  }

  public class MyAccountDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
        Account.Name => 'My Test Account'
      };
    }
  }

  public class ContactDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
        Contact.FirstName => 'First',
        Contact.LastName  => 'Last'
      };
    }
  }
    
    public class LeadDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
        Lead.FirstName => 'First',
        Lead.LastName  => 'Last',
            Lead.Phone => '(555)555-5555',
            Lead.Email => 'testEmailAddress@example.com',
            Lead.Company => 'Test Company'
      };
    }
  }

  public class OpportunityDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
        Opportunity.Name      => 'Test Opportunity',
        Opportunity.StageName => 'Closed Won',
        Opportunity.CloseDate => System.today()
      };
    }
  }

  public class CaseDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
        Case.Subject => 'Test Case'
      };
    }
  }
    
    public class DS_PackagesTouchpointDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
            Touchpoint__c.Name => 'Test Touchpoint',
            Touchpoint__c.Instructions__c => 'Test Instructions',
                Touchpoint__c.Status__c => 'Open',
                Touchpoint__c.Number__c => 1,
                Touchpoint__c.Due_Date_Time__c => system.now()
                };
    }
  }
    
    public class DS_PackagesCadenceDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
            Cadence__c.Name => 'Test Cadence',
            Cadence__c.Active__c => true,
            Cadence__c.Business_Hours__c => [Select Id From BusinessHours Limit 1].Id,
            Cadence__c.Number_of_Steps__c => 4
                };
    }
  }
    
    public class DS_PackagesCadenceStepDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
            Cadence_Step__c.Name => 'Test Cadence Step',
                Cadence_Step__c.Days__c => 1,
                Cadence_Step__c.Hours__c => 8,
                Cadence_Step__c.Instructions__c => 'Test Instructions'
                };
    }
  }
    
    public class DS_PackagesCadenceMemberDefaults implements TestFactory.FieldDefaults {
    public Map<Schema.SObjectField, Object> getFieldDefaults() {
      return new Map<Schema.SObjectField, Object> {
            Cadence_Member__c.Name => 'Test Cadence Member',
                Cadence_Member__c.Active__c => true,
                Cadence_Member__c.Status__c => 'Not Started'
                };
    }
  }
}