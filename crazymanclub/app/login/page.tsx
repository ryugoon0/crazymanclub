"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function Login() {
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [msg, setMsg] = useState("");
  const router = useRouter();

  async function login() {
    const cleanLoginId = loginId.trim().toLowerCase();

    if (!cleanLoginId) {
      setMsg("아이디를 입력해주세요.");
      return;
    }

    if (!password) {
      setMsg("비밀번호를 입력해주세요.");
      return;
    }

    setMsg("로그인 중...");

    const { data, error } = await supabase.rpc("login_member", {
      p_login_id: cleanLoginId,
      p_password: password,
    });

    if (error) {
      setMsg(error.message);
      return;
    }

    if (!data || data.length === 0) {
      setMsg("아이디 또는 비밀번호가 올바르지 않습니다.");
      return;
    }

    const member = data[0];

    if (!member.approved) {
      setMsg("운영진 승인 후 이용 가능합니다.");
      return;
    }

    localStorage.setItem("cmc_member", JSON.stringify(member));

    router.push("/upload");
  }

  return (
    <main className="wrap">
      <section className="header">
        <div>
          <h1>로그인</h1>
          <p>아이디와 비밀번호로 로그인합니다.</p>
        </div>
        <div className="nav">
          <Link href="/">홈</Link>
          <Link href="/signup">회원가입</Link>
        </div>
      </section>

      <section className="panel">
        <div className="form">
          <label>아이디</label>
          <input
            value={loginId}
            onChange={(e) => setLoginId(e.target.value)}
            placeholder="예: haejun"
          />

          <label>비밀번호</label>
          <input
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
          />

          <button className="primary" onClick={login}>
            로그인
          </button>

          {msg && <div className="notice">{msg}</div>}
        </div>
      </section>
    </main>
  );
}