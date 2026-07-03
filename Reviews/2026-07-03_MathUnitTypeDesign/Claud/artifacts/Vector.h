#pragma once

#include "Core/Public/Math/Mathf.h"

// ============================================================================
// Vector
// ----------------------------------------------------------------------------
// CyphenEngine 3D 월드 좌표를 표현하는 float 기반 값 타입입니다.
//
// Unity식 사용자 직관을 기본으로 합니다.
//     +X는 오른쪽입니다.
//     +Y는 위쪽입니다.
//     +Z는 화면 안쪽이자 월드의 앞쪽입니다.
//     좌표계는 왼손좌표계입니다.
// ============================================================================

struct Vector
{
	float x = 0.0f;
	float y = 0.0f;
	float z = 0.0f;

	constexpr Vector() = default;

	constexpr Vector(float inX, float inY, float inZ)
		: x(inX)
		, y(inY)
		, z(inZ)
	{
	}

	static constexpr Vector Zero()
	{
		return Vector(0.0f, 0.0f, 0.0f);
	}

	static constexpr Vector One()
	{
		return Vector(1.0f, 1.0f, 1.0f);
	}

	static constexpr Vector Right()
	{
		return Vector(1.0f, 0.0f, 0.0f);
	}

	static constexpr Vector Up()
	{
		return Vector(0.0f, 1.0f, 0.0f);
	}

	static constexpr Vector Forward()
	{
		return Vector(0.0f, 0.0f, 1.0f);
	}

	constexpr float SqrMagnitude() const
	{
		return x * x + y * y + z * z;
	}

	float Magnitude() const
	{
		return Mathf::Sqrt(SqrMagnitude());
	}

	Vector Normalized() const
	{
		const float magnitude = Magnitude();

		if (magnitude <= Mathf::Epsilon)
		{
			return Zero();
		}

		return Vector(x / magnitude, y / magnitude, z / magnitude);
	}

	static constexpr float Dot(const Vector& left, const Vector& right)
	{
		return left.x * right.x + left.y * right.y + left.z * right.z;
	}

	// 외적입니다. 왼손좌표계 기준으로 Right x Up == Forward가 성립합니다.
	static constexpr Vector Cross(const Vector& left, const Vector& right)
	{
		return Vector(
			left.y * right.z - left.z * right.y,
			left.z * right.x - left.x * right.z,
			left.x * right.y - left.y * right.x);
	}

	static constexpr float SqrDistance(const Vector& left, const Vector& right)
	{
		return (right.x - left.x) * (right.x - left.x)
			+ (right.y - left.y) * (right.y - left.y)
			+ (right.z - left.z) * (right.z - left.z);
	}

	static float Distance(const Vector& left, const Vector& right)
	{
		return Mathf::Sqrt(SqrDistance(left, right));
	}

	// t를 0~1로 강제하지 않는 비클램프 보간입니다. Mathf::Lerp와 동일한 정책입니다.
	static constexpr Vector Lerp(const Vector& from, const Vector& to, float t)
	{
		return Vector(
			from.x + (to.x - from.x) * t,
			from.y + (to.y - from.y) * t,
			from.z + (to.z - from.z) * t);
	}

	// 성분별 근사 동등 비교입니다. 정확한 operator== 대신 float 오차를 허용합니다.
	static bool Approximately(const Vector& left, const Vector& right)
	{
		return Mathf::Approximately(left.x, right.x)
			&& Mathf::Approximately(left.y, right.y)
			&& Mathf::Approximately(left.z, right.z);
	}

	Vector& operator+=(const Vector& other)
	{
		x += other.x;
		y += other.y;
		z += other.z;

		return *this;
	}

	Vector& operator-=(const Vector& other)
	{
		x -= other.x;
		y -= other.y;
		z -= other.z;

		return *this;
	}

	Vector& operator*=(float scalar)
	{
		x *= scalar;
		y *= scalar;
		z *= scalar;

		return *this;
	}

	Vector& operator/=(float scalar)
	{
		x /= scalar;
		y /= scalar;
		z /= scalar;

		return *this;
	}
};

static_assert(sizeof(Vector) == sizeof(float) * 3, "Vector must remain tight 12-byte storage.");
static_assert(alignof(Vector) == alignof(float), "Vector storage must not add default SIMD alignment.");

constexpr Vector operator+(const Vector& left, const Vector& right)
{
	return Vector(left.x + right.x, left.y + right.y, left.z + right.z);
}

constexpr Vector operator-(const Vector& left, const Vector& right)
{
	return Vector(left.x - right.x, left.y - right.y, left.z - right.z);
}

constexpr Vector operator-(const Vector& vector)
{
	return Vector(-vector.x, -vector.y, -vector.z);
}

constexpr Vector operator*(const Vector& vector, float scalar)
{
	return Vector(vector.x * scalar, vector.y * scalar, vector.z * scalar);
}

constexpr Vector operator*(float scalar, const Vector& vector)
{
	return vector * scalar;
}

constexpr Vector operator/(const Vector& vector, float scalar)
{
	return Vector(vector.x / scalar, vector.y / scalar, vector.z / scalar);
}

constexpr bool operator==(const Vector& left, const Vector& right)
{
	return left.x == right.x && left.y == right.y && left.z == right.z;
}

constexpr bool operator!=(const Vector& left, const Vector& right)
{
	return !(left == right);
}

// 좌표계 회귀 방지입니다. 누군가 부호나 축 정의를 흔들면 컴파일이 막힙니다.
static_assert(Vector::Cross(Vector::Right(), Vector::Up()) == Vector::Forward(),
	"Left-handed basis: Right x Up must equal Forward.");
