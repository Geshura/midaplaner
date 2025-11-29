public class User {
    String username;
    String password;
    Role role;

    User(String username, String password, Role role) {
        this.username = username;
        this.password = password;
        this.role = role;
    }
}
