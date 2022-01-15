package com.xnsio.filter;

import generated.CustomerRecords;
import generated.QueryResult;

import java.util.List;

public class BucketCustomers {
    public CustomerRecords segregate(QueryResult queryResult) {
        CustomerRecords customerRecords = new CustomerRecords();
        CustomerRecords.EvenData evenData = new CustomerRecords.EvenData();
        CustomerRecords.OddData oddData = new CustomerRecords.OddData();
        for (QueryResult.Record record: queryResult.getRecord()) {
            List<CustomerRecords.EvenData.Customer> evenCustomers = evenData.getCustomer();
            CustomerRecords.EvenData.Customer evenCustomer = new CustomerRecords.EvenData.Customer();

            List<CustomerRecords.OddData.Customer> oddCustomers = oddData.getCustomer();

            CustomerRecords.OddData.Customer oddCustomer = new CustomerRecords.OddData.Customer();
            for (QueryResult.Record.Property property :
                    record.getProperty()) {
                if (property.getKey() % 2 == 0) {
                    List<CustomerRecords.EvenData.Customer.Key> keys = evenCustomer.getKey();
                    CustomerRecords.EvenData.Customer.Key even = new CustomerRecords.EvenData.Customer.Key();
                    even.setId(property.getKey());
                    even.setValue(property.getValue());
                    keys.add(even);
                } else {
                    List<CustomerRecords.OddData.Customer.Key> keys = oddCustomer.getKey();
                    CustomerRecords.OddData.Customer.Key odd = new CustomerRecords.OddData.Customer.Key();
                    odd.setId(property.getKey());
                    odd.setValue(property.getValue());
                    keys.add(odd);
                }
            }
            if (!evenCustomer.getKey().isEmpty()) {
                evenCustomer.setId(record.getId());
                evenCustomers.add(evenCustomer);
            }
            if(!oddCustomer.getKey().isEmpty()) {
                oddCustomer.setId(record.getId());
                oddCustomers.add(oddCustomer);
            }
        }
        if (!evenData.getCustomer().isEmpty()) {
            customerRecords.setEvenData(evenData);
        }
        if (!oddData.getCustomer().isEmpty()) {
            customerRecords.setOddData(oddData);
        }
        return customerRecords;
    }
}
