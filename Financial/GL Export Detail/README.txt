This reports provides detail on items exported to GL grouped and summarized by GL Account number.

Input Parameters:  Transaction Date Range, Entry Date Range, Export Date Range, Accounts, Services

KNOWN ISSUES:  
-  I was not successful in getting the Accounts and Services multi-value selections to properly fitler in the SQL WHERE clause, 
instead it is filtering in the presentation layer.  This means the report is less-efficient than it could be and takes longer to load.

- If a Product/Service has non-compliant XML characters (&,<,>) in the description, the report will error out... I know there should be an easy way
correct this in SQL but since we only had one offending Service, I just renamed it....call me lazy :P
