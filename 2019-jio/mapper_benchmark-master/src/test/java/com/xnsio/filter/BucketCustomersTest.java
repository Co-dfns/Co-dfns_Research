package com.xnsio.filter;

import generated.CustomerRecords;
import generated.QueryResult;
import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.*;

class BucketCustomersTest {

    @Test
    void even_customer_exists() {
        QueryResult queryResult = new QueryResult();
        List<QueryResult.Record> records = queryResult.getRecord();
        QueryResult.Record someCustomer = new QueryResult.Record();
        someCustomer.setId("WEBDW");
        List<QueryResult.Record.Property> properties = someCustomer.getProperty();
        QueryResult.Record.Property p = new QueryResult.Record.Property();
        p.setKey(2);
        p.setValue("BSEFQPINLICBHSHO");
        properties.add(p);
        records.add(someCustomer);

        CustomerRecords segregatedRecords = new BucketCustomers().segregate(queryResult);
        assertNotNull(segregatedRecords.getEvenData());
        assertEquals("WEBDW", segregatedRecords.getEvenData().getCustomer().get(0).getId());
        assertEquals("BSEFQPINLICBHSHO", segregatedRecords.getEvenData().getCustomer().get(0).getKey().get(0).getValue());
    }
    @Test
    void odd_customer_exists() {
        QueryResult queryResult = new QueryResult();
        List<QueryResult.Record> records = queryResult.getRecord();
        QueryResult.Record someCustomer = new QueryResult.Record();
        someCustomer.setId("WEBDW");
        List<QueryResult.Record.Property> properties = someCustomer.getProperty();
        QueryResult.Record.Property p = new QueryResult.Record.Property();
        p.setKey(1);
        p.setValue("ECIVFZLEQIWSZBRD");
        properties.add(p);
        records.add(someCustomer);

        CustomerRecords segregatedRecords = new BucketCustomers().segregate(queryResult);
        assertNotNull(segregatedRecords.getOddData());
        assertEquals("WEBDW", segregatedRecords.getOddData().getCustomer().get(0).getId());
        assertEquals("ECIVFZLEQIWSZBRD", segregatedRecords.getOddData().getCustomer().get(0).getKey().get(0).getValue());
    }
}