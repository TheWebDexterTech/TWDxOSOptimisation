<?xml version="1.0" encoding="UTF-16"?>
<!--
  TWDxOSOptimisation - Task Scheduler export template for the Declutter.ps1
  weekly job. Install.ps1 creates this task programmatically via
  Register-ScheduledTask instead of importing this file directly - this
  template is kept for reference / manual `schtasks /create /xml` use, and
  documents the same trigger shape Install.ps1 builds at runtime.

  Placeholders (substituted the same way Bash templates use __VAR__):
    __CLEANUP_HOUR__    - hour component of CleanupTime (0-23)
    __CLEANUP_MINUTE__  - minute component of CleanupTime (0-59)
    __SCRIPT_PATH__     - full path to the installed Declutter.ps1
-->
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>TWDxOSOptimisation weekly cleanup (Declutter.ps1)</Description>
    <URI>\TWDxOSOptimisation-Declutter</URI>
  </RegistrationInfo>
  <Triggers>
    <CalendarTrigger>
      <StartBoundary>2026-01-04T__CLEANUP_HOUR__:__CLEANUP_MINUTE__:00</StartBoundary>
      <Enabled>true</Enabled>
      <ScheduleByWeek>
        <DaysOfWeek>
          <Sunday />
        </DaysOfWeek>
        <WeeksInterval>1</WeeksInterval>
      </ScheduleByWeek>
    </CalendarTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <StartWhenAvailable>true</StartWhenAvailable>
    <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
    <WakeToRun>false</WakeToRun>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -ExecutionPolicy Bypass -File "__SCRIPT_PATH__" -Apply</Arguments>
    </Exec>
  </Actions>
</Task>
