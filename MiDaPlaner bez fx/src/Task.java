import java.util.*;

public class Task {
    String title;
    Status status = Status.TO_DO;
    List<Milestone> milestones = new ArrayList<>();

    Task(String title) {
        this.title = title;
    }

    double getProgress() {
        if (milestones.isEmpty()) return status == Status.DONE ? 100 : 0;
        int done = 0;
        for(Milestone m : milestones) if(m.completed) done++;
        return (double) done / milestones.size() * 100;
    }
}
