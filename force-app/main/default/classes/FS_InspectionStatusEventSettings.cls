/**
 * @description Loads FS_Inspection_Status_Event_Setting__mdt Default_Setting and exposes
 * parsed publication settings used by the Inspection Data Update publisher.
 */
public inherited sharing class FS_InspectionStatusEventSettings {
  private static final String DEFAULT_DEVELOPER_NAME = 'Default_Setting';
  private static final String DEFAULT_EVENT_TYPE = 'InspectionStatusUpdate';
  private static final String DEFAULT_UNSCHEDULED_STATUS = 'None';

  /**
   * @description Test-only CMDT override so tests do not depend on org Default_Setting values.
   */
  @TestVisible
  private static FS_Inspection_Status_Event_Setting__mdt settingsOverride;

  /**
   * @description Test hook that simulates a missing Default_Setting record.
   */
  @TestVisible
  private static Boolean forceMissingSettingForTest = false;

  /**
   * @description Parsed publication settings used by the trigger action.
   */
  public class Config {
    public Boolean isActive;
    public String eventType;
    public String unscheduledStatus;
  }

  /**
   * @description Returns Default_Setting, or the test override when set.
   * @return The setting record, or null if none exists.
   */
  @TestVisible
  public static FS_Inspection_Status_Event_Setting__mdt getDefaultSetting() {
    if (forceMissingSettingForTest) {
      return null;
    }
    if (settingsOverride != null) {
      return settingsOverride;
    }
    return FS_Inspection_Status_Event_Setting__mdt.getInstance(DEFAULT_DEVELOPER_NAME);
  }

  /**
   * @description Builds a Config from Default_Setting with safe defaults when fields are blank.
   * @return Parsed configuration. isActive defaults to true when no CMDT record exists.
   */
  public static Config getConfig() {
    FS_Inspection_Status_Event_Setting__mdt setting = getDefaultSetting();
    if (setting == null) {
      return buildDefaultConfig();
    }
    return buildConfigFromSetting(setting);
  }

  /**
   * @description Packaged defaults used when Default_Setting is missing.
   * @return Parsed configuration.
   */
  private static Config buildDefaultConfig() {
    Config config = new Config();
    config.isActive = true;
    config.eventType = DEFAULT_EVENT_TYPE;
    config.unscheduledStatus = DEFAULT_UNSCHEDULED_STATUS;
    return config;
  }

  /**
   * @description Maps a CMDT record onto Config, applying defaults for blank text fields.
   * @param setting Default_Setting record.
   * @return Parsed configuration.
   */
  private static Config buildConfigFromSetting(
    FS_Inspection_Status_Event_Setting__mdt setting
  ) {
    Config config = new Config();
    config.isActive = setting.Is_Active__c == true;
    config.eventType = firstNonBlank(setting.Event_Type__c, DEFAULT_EVENT_TYPE);
    config.unscheduledStatus = firstNonBlank(
      setting.Unscheduled_Status__c,
      DEFAULT_UNSCHEDULED_STATUS
    );
    return config;
  }

  /**
   * @description Returns the first non-blank value.
   * @param primary Preferred value.
   * @param fallback Value used when primary is blank.
   * @return Non-blank string.
   */
  @TestVisible
  private static String firstNonBlank(String primary, String fallback) {
    if (String.isBlank(primary)) {
      return fallback;
    }
    return primary;
  }
}
