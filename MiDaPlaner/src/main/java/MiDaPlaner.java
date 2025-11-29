import javafx.application.Application;
import javafx.scene.Scene;
import javafx.scene.control.*;
import javafx.scene.layout.*;
import javafx.stage.Stage;
import javafx.geometry.Insets;
import javafx.geometry.Pos;
import java.util.*;

// --- MODELE ---
enum Role { MANAGER, EMPLOYEE }
enum Status { TO_DO, IN_PROGRESS, DONE }

class User {
    String username;
    String password;
    Role role;

    User(String username, String password, Role role) {
        this.username = username;
        this.password = password;
        this.role = role;
    }
}

class Milestone {
    String name;
    boolean completed;

    Milestone(String name) {
        this.name = name;
        this.completed = false;
    }
}

class Task {
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

class Column {
    String name;
    List<Task> tasks = new ArrayList<>();

    Column(String name) {
        this.name = name;
    }
}

class Board {
    String name;
    List<Column> columns = new ArrayList<>();

    Board(String name) {
        this.name = name;
    }
}

// --- SERWIS AUTORYZACJI ---
class AuthService {
    Map<String, User> users = new HashMap<>();

    User login(String u, String p) {
        User user = users.get(u);
        if(user != null && user.password.equals(p)) return user;
        return null;
    }

    boolean register(String u, String p, Role r) {
        if(users.containsKey(u)) return false;
        users.put(u, new User(u, p, r));
        return true;
    }
}

// --- APLIKACJA JavaFX ---
public class MiDaPlaner extends Application {
    AuthService auth = new AuthService();
    User currentUser;
    List<Board> boards = new ArrayList<>();

    @Override
    public void start(Stage primaryStage) {
        seedUsers();
        showLogin(primaryStage);
    }

    void seedUsers() {
        auth.register("manager","123",Role.MANAGER);
        auth.register("employee","123",Role.EMPLOYEE);
    }

    void showLogin(Stage stage) {
        stage.setTitle("MiDaPlaner Login");
        VBox root = new VBox(10);
        root.setPadding(new Insets(20));
        root.setAlignment(Pos.CENTER);

        TextField usernameField = new TextField();
        usernameField.setPromptText("Username");
        PasswordField passwordField = new PasswordField();
        passwordField.setPromptText("Password");

        Button loginBtn = new Button("Login");
        Button regBtn = new Button("Register");

        loginBtn.setOnAction(e -> {
            String u = usernameField.getText();
            String p = passwordField.getText();
            User user = auth.login(u,p);
            if(user != null) {
                currentUser = user;
                showMainMenu(stage);
            } else {
                showAlert("Błędne dane!");
            }
        });

        regBtn.setOnAction(e -> {
            String u = usernameField.getText();
            String p = passwordField.getText();
            if(auth.register(u,p,Role.EMPLOYEE)) showAlert("Zarejestrowano!");
            else showAlert("Użytkownik istnieje!");
        });

        root.getChildren().addAll(new Label("MiDaPlaner Login"), usernameField, passwordField, loginBtn, regBtn);
        stage.setScene(new Scene(root, 300, 250));
        stage.show();
    }

    void showMainMenu(Stage stage) {
        stage.setTitle("MiDaPlaner - " + currentUser.username);
        VBox root = new VBox(10);
        root.setPadding(new Insets(10));

        ListView<String> boardList = new ListView<>();
        updateBoardList(boardList);

        Button addBoardBtn = new Button("Add Board");
        Button openBoardBtn = new Button("Open Board");

        addBoardBtn.setOnAction(e -> {
            TextInputDialog dialog = new TextInputDialog();
            dialog.setHeaderText("Board Name:");
            Optional<String> result = dialog.showAndWait();
            result.ifPresent(name -> {
                Board b = new Board(name);
                boards.add(b);
                updateBoardList(boardList);
            });
        });

        openBoardBtn.setOnAction(e -> {
            int idx = boardList.getSelectionModel().getSelectedIndex();
            if(idx>=0) showBoardMenu(boards.get(idx));
        });

        root.getChildren().addAll(new Label("Boards:"), boardList, addBoardBtn, openBoardBtn);
        stage.setScene(new Scene(root, 400, 400));
    }

    void updateBoardList(ListView<String> list) {
        list.getItems().clear();
        for(Board b : boards) list.getItems().add(b.name);
    }

    void showBoardMenu(Board board) {
        Stage stage = new Stage();
        stage.setTitle("Board - " + board.name);
        VBox root = new VBox(10);
        root.setPadding(new Insets(10));

        ListView<String> colList = new ListView<>();
        updateColumnList(colList, board);

        Button addColBtn = new Button("Add Column");
        Button openColBtn = new Button("Open Column");

        addColBtn.setOnAction(e -> {
            TextInputDialog dialog = new TextInputDialog();
            dialog.setHeaderText("Column Name:");
            Optional<String> res = dialog.showAndWait();
            res.ifPresent(name -> {
                Column c = new Column(name);
                board.columns.add(c);
                updateColumnList(colList, board);
            });
        });

        openColBtn.setOnAction(e -> {
            int idx = colList.getSelectionModel().getSelectedIndex();
            if(idx>=0) showColumnMenu(board.columns.get(idx));
        });

        root.getChildren().addAll(new Label("Columns:"), colList, addColBtn, openColBtn);
        stage.setScene(new Scene(root, 400, 400));
        stage.show();
    }

    void updateColumnList(ListView<String> list, Board board) {
        list.getItems().clear();
        for(Column c : board.columns) list.getItems().add(c.name);
    }

    void showColumnMenu(Column column) {
        Stage stage = new Stage();
        stage.setTitle("Column - " + column.name);
        VBox root = new VBox(10);
        root.setPadding(new Insets(10));

        ListView<String> taskList = new ListView<>();
        updateTaskList(taskList, column);

        Button addTaskBtn = new Button("Add Task");
        Button editTaskBtn = new Button("Edit Task");

        addTaskBtn.setOnAction(e -> {
            TextInputDialog dialog = new TextInputDialog();
            dialog.setHeaderText("Task Title:");
            Optional<String> res = dialog.showAndWait();
            res.ifPresent(title -> {
                Task t = new Task(title);
                column.tasks.add(t);
                updateTaskList(taskList, column);
            });
        });

        editTaskBtn.setOnAction(e -> {
            int idx = taskList.getSelectionModel().getSelectedIndex();
            if(idx>=0) {
                Task t = column.tasks.get(idx);
                ChoiceDialog<String> choice = new ChoiceDialog<>(t.status.toString(), "TO_DO","IN_PROGRESS","DONE");
                choice.setHeaderText("Change Status:");
                Optional<String> res = choice.showAndWait();
                res.ifPresent(s -> {
                    t.status = Status.valueOf(s);
                    updateTaskList(taskList, column);
                });
            }
        });

        root.getChildren().addAll(new Label("Tasks:"), taskList, addTaskBtn, editTaskBtn);
        stage.setScene(new Scene(root, 400, 400));
        stage.show();
    }

    void updateTaskList(ListView<String> list, Column column) {
        list.getItems().clear();
        for(Task t : column.tasks) {
            list.getItems().add(t.title + " [" + t.status + "] - " + (int)t.getProgress() + "%");
        }
    }

    void showAlert(String msg) {
        Alert alert = new Alert(Alert.AlertType.INFORMATION, msg, ButtonType.OK);
        alert.showAndWait();
    }

    public static void main(String[] args) {
        launch(args);
    }
}
