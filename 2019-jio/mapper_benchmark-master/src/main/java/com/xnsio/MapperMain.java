package com.xnsio;

import com.xnsio.filter.BucketCustomers;
import generated.CustomerRecords;
import generated.QueryResult;

import javax.xml.bind.JAXBContext;
import javax.xml.bind.JAXBException;
import javax.xml.bind.Unmarshaller;
import java.io.File;
import java.io.IOException;
import java.net.URISyntaxException;
import java.util.ArrayList;
import java.util.List;

import static java.lang.Runtime.getRuntime;
import static java.lang.System.nanoTime;

public class MapperMain {

    public static final int ITERATIONS = 10_000;

    public static void main(String[] args) throws URISyntaxException, IOException, JAXBException, InterruptedException {

        QueryResult result = buildInput();

        execute(result);
    }

    private static List<CustomerRecords> execute(QueryResult result) throws InterruptedException {
        Runtime runtime = getRuntime();
        System.gc();
        Thread.sleep(2000);
        long startTime = nanoTime();
        long initialMemoryUsed = memUsed(runtime);
        List<CustomerRecords> perfResults = new ArrayList<>(ITERATIONS);
        for (int i = 0; i < ITERATIONS; i++) {
            perfResults.add(new BucketCustomers().segregate(result));
        }
        long timeElapsed = nanoTime() - startTime;
        long afterMemoryUsed = memUsed(runtime);
        System.out.print("Mem consumed " + (afterMemoryUsed - initialMemoryUsed) / (1024 * 1024) + " MB");
        System.out.println(" & Exec-time: " + (timeElapsed / 1000000) + " milli-secs");
        return perfResults;
    }

    private static long memUsed(Runtime runtime) {
        return runtime.totalMemory() - runtime.freeMemory();
    }

    private static QueryResult buildInput() throws URISyntaxException, JAXBException {
        JAXBContext jaxbContext = JAXBContext.newInstance(QueryResult.class);

        Unmarshaller unmarshaller = jaxbContext.createUnmarshaller();

        return (QueryResult) unmarshaller.unmarshal(MapperMain.class.getClassLoader().getResource("input.xml"));
    }
}
