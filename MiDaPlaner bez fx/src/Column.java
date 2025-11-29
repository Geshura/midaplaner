import java.util.*;

public class Column {
    String name;
    List<Task> tasks = new ArrayList<>();

    Column(String name) {
        this.name = name;
    }
}
