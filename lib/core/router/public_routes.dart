import 'app_routes.dart';

/// 匿名可访问路由的统一判定。
///
/// 公开面：白名单页、帖子详情 `/post/:postId`、用户主页 `/user/:userId`。
/// 发帖编辑器 `/post/new` 与编辑页 `/post/edit/:postId` 必须登录；
/// 判定顺序上先显式排除编辑器，再应用 `/post/` 前缀规则。
const publicRoutes = [
  AppRoutes.feed,
  AppRoutes.search,
  AppRoutes.login,
  AppRoutes.register,
];

/// 路由守卫据此判断 [location] 是否允许匿名访问；[location] 为不含查询串的路径。
bool isPublicRoute(String location) {
  if (publicRoutes.contains(location)) {
    return true;
  }
  if (location == AppRoutes.postNew) {
    return false;
  }
  if (location.startsWith('/post/') && !location.contains('/edit/')) {
    return true;
  }
  if (location.startsWith('/user/')) {
    return true;
  }
  return false;
}
