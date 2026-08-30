//! Status row data — same /proc sources as desktopdesigner's Bar
//! (Services/Sensors.qml), reimplemented here since this is a fully
//! independent Rust binary with no access to that QML service layer.

use std::fs;

pub struct CpuSample {
    idle: u64,
    total: u64,
}

pub fn read_cpu_sample() -> Option<CpuSample> {
    let content = fs::read_to_string("/proc/stat").ok()?;
    let line = content.lines().next()?;
    let parts: Vec<u64> = line
        .split_whitespace()
        .skip(1)
        .filter_map(|s| s.parse().ok())
        .collect();
    if parts.len() < 4 {
        return None;
    }
    let idle = parts[3] + parts.get(4).copied().unwrap_or(0);
    let total: u64 = parts.iter().sum();
    Some(CpuSample { idle, total })
}

pub fn cpu_percent(prev: &CpuSample, cur: &CpuSample) -> u32 {
    let d_total = cur.total.saturating_sub(prev.total);
    let d_idle = cur.idle.saturating_sub(prev.idle);
    if d_total == 0 {
        return 0;
    }
    (100 * (d_total.saturating_sub(d_idle)) / d_total) as u32
}

pub fn ram_percent() -> Option<u32> {
    let content = fs::read_to_string("/proc/meminfo").ok()?;
    let mut total = None;
    let mut available = None;
    for line in content.lines() {
        if let Some(v) = line.strip_prefix("MemTotal:") {
            total = v.trim().split_whitespace().next()?.parse::<u64>().ok();
        } else if let Some(v) = line.strip_prefix("MemAvailable:") {
            available = v.trim().split_whitespace().next()?.parse::<u64>().ok();
        }
    }
    let (total, available) = (total?, available?);
    if total == 0 {
        return None;
    }
    Some((100 * (total.saturating_sub(available)) / total) as u32)
}

pub fn battery_percent() -> Option<u32> {
    let raw = fs::read_to_string("/sys/class/power_supply/BAT0/capacity").ok()?;
    raw.trim().parse().ok()
}

pub fn uptime_string() -> Option<String> {
    let content = fs::read_to_string("/proc/uptime").ok()?;
    let secs: f64 = content.split_whitespace().next()?.parse().ok()?;
    let secs = secs as u64;
    let days = secs / 86400;
    let hours = (secs % 86400) / 3600;
    Some(if days > 0 {
        format!("{}d {}h", days, hours)
    } else {
        let minutes = (secs % 3600) / 60;
        format!("{}h {}m", hours, minutes)
    })
}
