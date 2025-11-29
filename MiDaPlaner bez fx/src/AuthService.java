import java.util.*;

public class AuthService {
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
