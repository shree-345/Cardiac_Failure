### Technical Challenges Faced  

Before using `crosstab()`, I needed to enable the `tablefunc` extension by running the following command in pgAdmin:  

```sql
CREATE EXTENSION IF NOT EXISTS tablefunc;
```  

To generate a pie chart in the output, I had to run the query in the PASQL tool instead of the Query tool.  

Understanding the dataset, its columns, medical terminology, and the relationships between tables was a significant challenge.  

Creating triggers, stored procedures, and functions was particularly difficult.  

Due to time constraints, I could not focus extensively on query optimization.  

To gain a foundational understanding of statistical functions such as `RANDOM_NORMAL`, `PERCENTILE_CONT`, and `STDDEV_SAMP`, I had to review multiple statistical concepts before writing queries.  

I also worked with complex functions such as `FIRST_VALUE`, `EXECUTE FORMAT`, `NTH_VALUE`, `NTILE`, and `CUME_DIST`, which required additional effort to implement effectively.

Listing some new functions used   

1.  EXTRACT  – Retrieves a specific part (year, month, day, etc.) from a date or timestamp.  
2.  CASE  – Implements conditional logic within SQL queries.  
3.  RANDOM  – Generates a random floating-point number between 0 and 1.  
4.  CONCAT  – Combines multiple string values into a single string.  
5.  Correlation  – Measures the statistical relationship between two numeric columns.  
6.  Data type casting  – Converts data from one type to another using `::type` or `CAST()`.  
7.  WIDTH_BUCKET  – Categorizes values into a specified number of buckets (bins).  
8.  REPEAT (bar chart)  – Repeats a string a specified number of times (useful for text-based bar charts).  
9.  pg_database_size  – Returns the size of a database in bytes.  
10.  lcm() and gcf()  – Calculates the least common multiple and greatest common factor of two numbers.  
11.  pg_size_pretty() and pg_relation_size('labs')  – Converts database size to a human-readable format and gets the size of a specific relation.  
12.  REVERSE  – Reverses a string.  
13.  FORMAT()  – Formats output in a structured way, often used for dynamic SQL queries.  
14.  CROSSTAB  – Transforms row-based data into a pivot table format.  
15.  FIRST_VALUE  – Retrieves the first value in an ordered window of data.  
16.  NTH_VALUE  – Returns the nth value in an ordered window of data.  
17.  LIMIT  – Restricts the number of rows returned in a query result.  
18.  NTILE  – Distributes rows into a specified number of equal-sized groups.  
19.  CUME_DIST  – Computes the cumulative distribution of a row within a partition.  
20.  Window Functions  – Perform calculations across a subset of rows related to the current row:  
   -  OVER()  – Defines a window for a function to operate over.  
   -  PARTITION BY  – Divides data into partitions for window functions.  
   -  ORDER BY  – Specifies the order of rows for window calculations.  
   -  RANK()  – Assigns a rank to rows with gaps for duplicates.  
   -  ROW_NUMBER()  – Assigns a unique sequential number to rows.  
21.  Common Table Expression (WITH)  – Creates temporary result sets for readability and reusability.  
22.  PERCENTILE_CONT  – Computes a percentile value using continuous distribution.  
23.  STDDEV_SAMP  – Calculates the sample standard deviation of a dataset.  
24.  RECURSIVE  – Enables recursive queries, often used for hierarchical data.  
25.  UNION ALL  – Combines the results of multiple queries without removing duplicates.  


