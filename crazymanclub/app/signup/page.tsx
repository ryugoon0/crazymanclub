"use client";

import { useState } from "react";
import { supabase } from "@/lib/supabase";
import { MEMBER_NAMES } from "@/lib/members";
import Link from "next/link";
import { useRouter } from "next/navigation";

export default function Signup() {
  const [loginId, setLoginId] = useState("");
  const [password, setPassword] = useState("");
  const [nickname, setNickname] = useState(MEMBER_NAMES[0]);
  const [msg, setMsg] = useState("");
  const router = useRouter();

  async function signup() {
    const cleanLoginId = loginId.trim().toLowerCase();
    const cleanNickname = nickname.trim();

    if (!/^[a-zA-Z0-9._-]{3,20}$/.test(cleanLoginId)) {
      setMsg("아이디는 영문, 숫자, 점, 언더바, 하이픈만 가능하며 3~20자로 입력해주세요.");
      return;
    }

    if (password.length < 6) {
      setMsg("비밀번호는 최소 6자리 이상 입력해주세요.");
      return;
    }

    if (!cleanNickname) {
      setMsg("닉네임을 선택해주세요.");
      return;
    }

    setMsg("가입 처리 중...");

    const { data, error } = await supabase.rpc("register_member", {
      p_login_id: cleanLoginId,
      p_password: password,
      p_nickname: cleanNickname,
    });

    if (error) {
      if (error.message.includes("members_login_id")) {
        setMsg("이미 사용 중인 아이디입니다.");
      } else if (error.message.includes("members_nickname")) {
        setMsg("이미 가입 신청된 닉네임입니다.");
      } else if (error.message.includes("duplicate key")) {
        setMsg("이미 사용 중인 아이디 또는 닉네임입니다.");
      } else {
        setMsg(error.message);
      }
      return;
    }

    if (!data || data.length === 0) {
      setMsg("회원가입 처리 중 문제가 발생했습니다.");
      return;
    }

    setMsg("가입 완료. 운영진 승인 후 로그인 가능합니다.");

    setTimeout(() => {
      router.push("/login");
    }, 1200);
  }

  return (
    <main className="wrap">
      <section className="header">
        <div>
          <h1>회원가입</h1>
          <p>아이디와 비밀번호를 입력하고, 닉네임은 명단에서 선택합니다.</p>
        </div>

        <div className="nav">
          <Link href="/">홈</Link>
          <Link href="/login">로그인</Link>
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
            placeholder="6자리 이상"
          />

          <label>캐릭터명 / 닉네임</label>
          <select value={nickname} onChange={(e) => setNickname(e.target.value)}>
            {MEMBER_NAMES.map((name) => (
              <option key={name} value={name}>
                {name}
              </option>
            ))}
          </select>

          <button className="primary" onClick={signup}>
            회원가입
          </button>

          {msg && <div className="notice">{msg}</div>}
        </div>
      </section>
    </main>
  );
}