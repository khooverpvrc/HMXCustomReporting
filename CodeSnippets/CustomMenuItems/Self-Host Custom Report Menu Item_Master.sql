/*
This is a template SQL query and you must enter the correct values as defined below. 
Open this script in SQL Server Management Studio and immediately save the script 
using a DIFFERENT name. Select Query > Specify Values for Template Parameters…

Enter the values as defined below – you may want to use the Custom Menu Item matrix 
to document these values prior to defining the values in the script.

All text or character values, except as noted, must be entered in single quotes.

[Meta Name] - The name of the Meta database for the Vision enterprise instance for which 
you will be adding the custom menu item. Do NOT use single quotes around this entry.

[Client Secure] - This is the name of the client or enterprise specific secure database. 
This database is typically named xxxSecure. Do NOT use single quotes around this entry. 
You MUST have a dedicated client secure database for EACH instance of Vision. It must be 
a one to one relationship between each Enterprise Record in WCSecure.dbo.Enterprises and 
the xxxSecure database.

[Menu Item Name] (50 characters)- Please enter the name of the report as it should display 
in the menu selection page. This is what will be displayed in the menu structure as well as in the 
Role/User security setting.

[Page Title] (150 characters)- This is the header or title that will be displayed on the report selection screen.

[Help Text] (150 characters)– This is the description that is displayed below the report name. If left blank it 
will use the Report Name as entered above.

[RDL File Name] (50 characters)– This is the actual report name without the .rdl extension or the HMX tag.

[Report Group] - There are four areas for custom reports and each is listed below. 
Please enter the appropriate location description. The script will automatically assign the 
correct ServiceGroupSys based on this description. 

•	Census
•	Scheduling
•	Clinical
•	Financial

[Sequence] – This is the order that the service will be diplayed within the Custom Reports list.  
If none is entered it will default to the next highest value available and the report will be 
the last in the list. If you wish to re-order these values once the report is in place please 
refer to the “Ordering of Custom Menu Items” documentation.

[Report Server Enabled] – This is ONLY for clients using a separate reporting server. Please 
contact your CSC to coordinate assistance if needed. The default is ‘NO’ and should ONLY be set 
to ‘YES’ if you are using a dedicated reporting database.


*/

Print 'Begin Custom Menu Item Creation'
Print ''
Go


Use <[Meta Name], varchar(50),>
Go

Declare @ServiceSys int
Declare @ServiceGroupSys int
Declare @ReportServerEnabled bit
Declare @Sequence int

Set @ReportServerEnabled = 
	(Case
		When <[Report Server Enabled],varchar(3),'No'> = 'No' Then 0
		When <[Report Server Enabled],varchar(3),'No'> = 'Yes' Then 1
		Else 0
	End)

Set @ServiceGroupSys =
	(Case
		When <[Report Group],varchar(20),''> = 'Census' Then 380
		When <[Report Group],varchar(20),''> = 'Scheduling' Then 381
		When <[Report Group],varchar(20),''> = 'Clinical' Then 382
		When <[Report Group],varchar(20),''> = 'Financial' Then 383
		Else 0
	End)

If @ServiceGroupSys <> 0 Begin
	If Not Exists (Select * from [dbo].Services with (nolock) Where [Service] = <[Menu Item Name],varchar(50),''>) Begin

		Insert Into [dbo].Services
				([Service],
				ServiceGroupSys, 
				[Sequence], 
				RequiresPatientSelection, 
				HREF, 
				MenuID, 
				HelpText, 
				ServiceLongName, 
				ServiceProviderSys, 
				IsActive, 
				IsCustom, 
				IsStaffOnly, 
				ReportServerEnabled, 
				SecurityAccessTypes,
				FrameSys, 
				ServiceTypeSys)
		Select
				<[Menu Item Name],varchar(50),''> as [Service], 
				@ServiceGroupSys as ServiceGroupSys, 
				<[Sequence],Int, 0> as [Sequence], 
				0 as RequiresPatientSelection,
				'Reports/ReportSel.aspx?RDL=@WorkFileLocation~Reports~CustomReports~' + Cast(<[RDL File Name],varchar(50),''> as varchar(50)) as HREF, 
				Null as MenuID,
				IsNULL(<[Help Text], varchar(150),''>,<[Menu Item Name],varchar(50),''>) as HelpText, 
				IsNULL(<[Page Title],varchar(150),''>,<[Menu Item Name],varchar(50),''>) as ServiceLongName, 
				2 as ServiceProviderSys,
				1 as IsActive,
				1 as IsCustom, 
				0 as IsStaffOnly, 
				@ReportServerEnabled as ReportServerEnabled, 
				7 as SecurityAccessTypes,
				'CustomReport' as FrameSys,
				1 as ServiceTypeSys

		Print 'Created Menu Item ' + <[Menu Item Name],varchar(50),''>
		Print ''

		Set @ServiceSys = @@Identity

	End Else Begin

		Print 'Menu Item already exists. New item not created. Checking for new location request'

	End

	If @ServiceSys = 0 Begin

		Set @ServiceSys = (Select ServiceSys From dbo.Services Where Services.[Service] = <[RDL File Name],varchar(50),''> and Services.IsCustom = 1)
	
	End

	If @ServiceSys <> 0 Begin

		IF NOT EXISTS(SELECT ServiceGroupSys FROM dbo.ServiceGroupServices WHERE ServiceGroupServices.ServiceGroupSys = @ServiceGroupSys 
																				AND ServiceGroupServices.ServiceSys = @ServiceSys) BEGIN

			IF <[Sequence],Int, 0> = 0 BEGIN
				Set @Sequence = (
						Select 
							IsNULL(Max(Sequence),0) + 10 as NewSequenceNum 
						From 
							ServiceGroupServices 
						Where 
							ServiceGroupServices.ServiceGroupSys = @ServiceGroupSys)
			End Else Begin
				Set @Sequence = <[Sequence],Int, 0>
			End

			INSERT INTO ServiceGroupServices(ServiceGroupSys, ServiceSys, [Sequence])
				VALUES (@ServiceGroupSys, @ServiceSys, @Sequence)
				Print <[Menu Item Name], varchar(50),''> + ' added to ' + <[Report Group],varchar(20),''> + ' custom reports'
		END

		Use <[Client Secure], varchar(50), >

		If NOT EXISTS(Select ServiceSys From ServiceOptions WHERE ServiceSys = @ServiceSys) Begin
				Insert Into ServiceOptions (ServiceSys, UseReportingServer, CustomEnabled, ImageSys, UserUpdated, DateUpdated)
					VALUES (@ServiceSys, @ReportServerEnabled, 1, Null, -1, getdate())
				Print 'Inserted Service Options Record in Client Secure database '
				Print ''
		End

	END Else Begin
	
		Print 'Service / menu item not found and not inserted. Error'
		Print ''
	END

End Else Begin

		Print 'Menu item not created. Incorrect or missing Report Group definition'
		Print ''

End

Print 'End Custom Menu Items Creation'

Go

