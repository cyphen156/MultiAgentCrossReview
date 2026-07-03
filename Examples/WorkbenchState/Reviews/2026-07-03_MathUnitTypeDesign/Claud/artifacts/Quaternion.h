#pragma once

#include "Core/Public/Math/Mathf.h"
#include "Core/Public/Math/Vector.h"

// ============================================================================
// Quaternion
// ----------------------------------------------------------------------------
// 3D 회전을 표현하는 float 기반 값 타입입니다. (x, y, z, w), w가 스칼라부입니다.
// 짐벌락이 없고, 곱으로 회전을 합성하며, 항등 회전은 (0, 0, 0, 1)입니다.
//
// 왼손좌표계 기준이며, +Z축 둘레 +theta 회전은 +X를 +Y로 보냅니다
// (Vector2D::Perpendicular 관례와 일치). 2D 월드는 FromAngleZ만 씁니다.
// ============================================================================

struct Quaternion
{
	float x = 0.0f;
	float y = 0.0f;
	float z = 0.0f;
	float w = 1.0f;

	constexpr Quaternion() = default;

	constexpr Quaternion(float inX, float inY, float inZ, float inW)
		: x(inX)
		, y(inY)
		, z(inZ)
		, w(inW)
	{
	}

	static constexpr Quaternion Identity()
	{
		return Quaternion(0.0f, 0.0f, 0.0f, 1.0f);
	}

	// 정규화된 축 둘레로 radians만큼 회전하는 쿼터니언입니다.
	static Quaternion FromAxisAngle(const Vector& axis, float radians)
	{
		const float half = radians * 0.5f;
		const float s = Mathf::Sin(half);

		return Quaternion(axis.x * s, axis.y * s, axis.z * s, Mathf::Cos(half));
	}

	// +Z축 둘레 회전입니다. 2D 월드에서 쓰는 유일한 회전입니다.
	static Quaternion FromAngleZ(float radians)
	{
		const float half = radians * 0.5f;

		return Quaternion(0.0f, 0.0f, Mathf::Sin(half), Mathf::Cos(half));
	}

	constexpr float SqrMagnitude() const
	{
		return x * x + y * y + z * z + w * w;
	}

	float Magnitude() const
	{
		return Mathf::Sqrt(SqrMagnitude());
	}

	Quaternion Normalized() const
	{
		const float magnitude = Magnitude();

		if (magnitude <= Mathf::Epsilon)
		{
			return Identity();
		}

		return Quaternion(x / magnitude, y / magnitude, z / magnitude, w / magnitude);
	}

	// 켤레입니다. 단위 쿼터니언에서는 역회전과 같습니다.
	constexpr Quaternion Conjugate() const
	{
		return Quaternion(-x, -y, -z, w);
	}

	// 이 회전을 벡터에 적용합니다.
	Vector Rotate(const Vector& v) const
	{
		const Vector u(x, y, z);
		const Vector t = 2.0f * Vector::Cross(u, v);

		return v + w * t + Vector::Cross(u, t);
	}
};

static_assert(sizeof(Quaternion) == sizeof(float) * 4, "Quaternion must remain tight 16-byte storage.");

// 회전 합성입니다. (a * b)는 b를 먼저, a를 나중에 적용하는 회전입니다.
constexpr Quaternion operator*(const Quaternion& a, const Quaternion& b)
{
	return Quaternion(
		a.w * b.x + a.x * b.w + a.y * b.z - a.z * b.y,
		a.w * b.y - a.x * b.z + a.y * b.w + a.z * b.x,
		a.w * b.z + a.x * b.y - a.y * b.x + a.z * b.w,
		a.w * b.w - a.x * b.x - a.y * b.y - a.z * b.z);
}
