// T7: 字符串处理（与 zfy/task7 语义一致）
fn main() {
    let mut s = String::new();
    for i in 0..3000i32 {
        s.push_str("w");
        s.push_str(&(i % 10).to_string());
        s.push_str("ab ");
    }
    let toks: Vec<&str> = s.split(' ').collect();
    let mut cnt: i64 = 0;
    let mut total: i64 = 0;
    for t in &toks {
        total += t.len() as i64;
        if t.find('a').is_some() { cnt += 1; }
    }
    println!("T7 total={} cnt={} slen={}", total, cnt, s.len());
}
