#pragma once

#include "Core/Public/Math/Vector.h"
#include "Core/Public/Math/Quaternion.h"

// ============================================================================
// Matrix4x4
// ----------------------------------------------------------------------------
// 3D 어파인 변환을 표현하는 float 기반 4x4 행렬입니다. (동차좌표)
//
// 레이아웃 규약 (DirectXMath 정렬):
//     row-major 저장, row-vector 규약 (v' = v * M).
//     이동 성분은 마지막 행 m[3]에 들어간다.
//     합성 순서 world = Scale * Rotate * Translate (v * S * R * T).
// ============================================================================

struct Matrix4x4
{
	// m[row][col], row-major.
	float m[4][4];

	constexpr Matrix4x4()
		: m{
			{ 1.0f, 0.0f, 0.0f, 0.0f },
			{ 0.0f, 1.0f, 0.0f, 0.0f },
			{ 0.0f, 0.0f, 1.0f, 0.0f },
			{ 0.0f, 0.0f, 0.0f, 1.0f } }
	{
	}

	constexpr Matrix4x4(
		float m00, float m01, float m02, float m03,
		float m10, float m11, float m12, float m13,
		float m20, float m21, float m22, float m23,
		float m30, float m31, float m32, float m33)
		: m{
			{ m00, m01, m02, m03 },
			{ m10, m11, m12, m13 },
			{ m20, m21, m22, m23 },
			{ m30, m31, m32, m33 } }
	{
	}

	static constexpr Matrix4x4 Identity()
	{
		return Matrix4x4();
	}

	static constexpr Matrix4x4 FromTranslation(const Vector& t)
	{
		return Matrix4x4(
			1.0f, 0.0f, 0.0f, 0.0f,
			0.0f, 1.0f, 0.0f, 0.0f,
			0.0f, 0.0f, 1.0f, 0.0f,
			t.x,  t.y,  t.z,  1.0f);
	}

	static constexpr Matrix4x4 FromScale(const Vector& s)
	{
		return Matrix4x4(
			s.x,  0.0f, 0.0f, 0.0f,
			0.0f, s.y,  0.0f, 0.0f,
			0.0f, 0.0f, s.z,  0.0f,
			0.0f, 0.0f, 0.0f, 1.0f);
	}

	// 단위 쿼터니언 -> 회전 행렬 (row-vector 규약).
	static Matrix4x4 FromRotation(const Quaternion& q)
	{
		const float xx = q.x * q.x;
		const float yy = q.y * q.y;
		const float zz = q.z * q.z;
		const float xy = q.x * q.y;
		const float xz = q.x * q.z;
		const float yz = q.y * q.z;
		const float wx = q.w * q.x;
		const float wy = q.w * q.y;
		const float wz = q.w * q.z;

		return Matrix4x4(
			1.0f - 2.0f * (yy + zz), 2.0f * (xy + wz),        2.0f * (xz - wy),        0.0f,
			2.0f * (xy - wz),        1.0f - 2.0f * (xx + zz), 2.0f * (yz + wx),        0.0f,
			2.0f * (xz + wy),        2.0f * (yz - wx),        1.0f - 2.0f * (xx + yy), 0.0f,
			0.0f,                    0.0f,                    0.0f,                    1.0f);
	}

	// world = Scale * Rotate * Translate.
	static Matrix4x4 Compose(const Vector& translation, const Quaternion& rotation, const Vector& scale);

	constexpr Matrix4x4 Transposed() const
	{
		return Matrix4x4(
			m[0][0], m[1][0], m[2][0], m[3][0],
			m[0][1], m[1][1], m[2][1], m[3][1],
			m[0][2], m[1][2], m[2][2], m[3][2],
			m[0][3], m[1][3], m[2][3], m[3][3]);
	}

	// 점 변환입니다. w = 1로 간주하므로 이동이 포함됩니다.
	constexpr Vector TransformPoint(const Vector& p) const
	{
		return Vector(
			p.x * m[0][0] + p.y * m[1][0] + p.z * m[2][0] + m[3][0],
			p.x * m[0][1] + p.y * m[1][1] + p.z * m[2][1] + m[3][1],
			p.x * m[0][2] + p.y * m[1][2] + p.z * m[2][2] + m[3][2]);
	}

	// 방향 변환입니다. w = 0으로 간주하므로 이동이 제외됩니다.
	constexpr Vector TransformDirection(const Vector& d) const
	{
		return Vector(
			d.x * m[0][0] + d.y * m[1][0] + d.z * m[2][0],
			d.x * m[0][1] + d.y * m[1][1] + d.z * m[2][1],
			d.x * m[0][2] + d.y * m[1][2] + d.z * m[2][2]);
	}
};

static_assert(sizeof(Matrix4x4) == sizeof(float) * 16, "Matrix4x4 must remain tight 64-byte storage.");

// 행렬 곱입니다. row-vector 규약에서 (A * B)는 A를 먼저, B를 나중에 적용합니다.
inline Matrix4x4 operator*(const Matrix4x4& a, const Matrix4x4& b)
{
	Matrix4x4 result = Matrix4x4::Identity();

	for (int row = 0; row < 4; ++row)
	{
		for (int col = 0; col < 4; ++col)
		{
			result.m[row][col] =
				a.m[row][0] * b.m[0][col] +
				a.m[row][1] * b.m[1][col] +
				a.m[row][2] * b.m[2][col] +
				a.m[row][3] * b.m[3][col];
		}
	}

	return result;
}

inline Matrix4x4 Matrix4x4::Compose(const Vector& translation, const Quaternion& rotation, const Vector& scale)
{
	return FromScale(scale) * FromRotation(rotation) * FromTranslation(translation);
}
