# flink-autobuild

An easy way to build [Flink-on-Tez](https://ci.apache.org/projects/flink/flink-docs-master/setup/flink_on_tez.html#setup) for dev purposes

    $ make dist install
    $ ./dist/flink/flink-tez org.apache.flink.tez.examples.WordCount  hdfs:///tmp/words/ hdfs:///tmp/wc/run-$RANDOM/

For those who want this to be fast - this isn't particularly fast. But that's easy to fix by collapsing the 1-1 edges in Flink to be in-memory, instead of over the network.
