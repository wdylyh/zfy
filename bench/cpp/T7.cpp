// T7: 字符串处理（与 zfy/task7 语义一致）
#include <cstdio>
#include <string>
#include <vector>
int main() {
    std::string s;
    for (int i = 0; i < 3000; i++) s += "w" + std::to_string(i % 10) + "ab ";
    std::vector<std::string> toks;
    size_t pos = 0;
    while (pos <= s.size()) {
        size_t sp = s.find(' ', pos);
        if (sp == std::string::npos) { toks.push_back(s.substr(pos)); break; }
        toks.push_back(s.substr(pos, sp - pos));
        pos = sp + 1;
    }
    long long cnt = 0, total = 0;
    for (auto& t : toks) {
        total += (long long)t.size();
        if (t.find('a') != std::string::npos) cnt++;
    }
    std::printf("T7 total=%lld cnt=%lld slen=%zu\n", total, cnt, s.size());
    return 0;
}
