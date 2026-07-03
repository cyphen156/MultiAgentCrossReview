#pragma once

#include "Core/Public/Math/Mathf.h"

// ============================================================================
// Vector2D
// ----------------------------------------------------------------------------
// CyphenEngine 2D 월드 좌표를 표현하는 float 기반 값 타입입니다.
//
// 월드 기본 좌표계:
//     원점은 좌하단입니다.
//     +X는 오른쪽입니다.
//     +Y는 위쪽입니다.
// ============================================================================

struct Vector2D
{
	float x = 0.0f;
	float y = 0.0f;

	constexpr Vector2D() = default;

	constexpr Vector2D(float inX, float inY)
		: x(inX)
		, y(inY)
	{
	}

	static constexpr Vector2D Zero()
	{
		return Vector2D(0.0f, 0.0f);
	}

	static constexpr Vector2D One()
	{
		return Vector2D(1.0f, 1.0f);
	}

	static constexpr Vector2D Right()
	{
		return Vector2D(1.0f, 0.0f);
	}

	static constexpr Vector2D Up()
	{
		return Vector2D(0.0f, 1.0f);
	}

	constexpr float SqrMagnitude() const
	{
		return x * x + y * y;
	}

	float Magnitude() const
	{
		return Mathf::Sqrt(SqrMagnitude());
	}

	Vector2D Normalized() const
	{
		const float magnitude = Magnitude();

		if (magnitude <= Mathf::Epsilon)
		{
			return Zero();
		}

		return Vector2D(x / magnitude, y / magnitude);
	}

	static constexpr float Dot(const Vector2D& left, const Vector2D& right)
	{
		return left.x * right.x + left.y * right.y;
	}

	// 2D 외적입니다. 3D cross의 z성분에 해당하는 스칼라이며, 부호로 회전 방향을 나타냅니다.
	static constexpr float Cross(const Vector2D& left, const Vector2D& right)
	{
		return left.x * right.y - left.y * right.x;
	}

	static constexpr float SqrDistance(const Vector2D& left, const Vector2D& right)
	{
		return (right.x - left.x) * (right.x - left.x)
			+ (right.y - left.y) * (right.y - left.y);
	}

	static float Distance(const Vector2D& left, const Vector2D& right)
	{
		return Mathf::Sqrt(SqrDistance(left, right));
	}

	// t를 0~1로 강제하지 않는 비클램프 보간입니다. Mathf::Lerp와 동일한 정책입니다.
	static constexpr Vector2D Lerp(const Vector2D& from, const Vector2D& to, float t)
	{
		return Vector2D(
			from.x + (to.x - from.x) * t,
			from.y + (to.y - from.y) * t);
	}

	// +90도(반시계) 회전입니다. +Y up 기준이며 (x, y) -> (-y, x)입니다.
	constexpr Vector2D Perpendicular() const
	{
		return Vector2D(-y, x);
	}

	// 성분별 근사 동등 비교입니다. 정확한 operator== 대신 float 오차를 허용합니다.
	static bool Approximately(const Vector2D& left, const Vector2D& right)
	{
		return Mathf::Approximately(left.x, right.x)
			&& Mathf::Approximately(left.y, right.y);
	}

	Vector2D& operator+=(const Vector2D& other)
	{
		x += other.x;
		y += other.y;

		return *this;
	}

	Vector2D& operator-=(const Vector2D& other)
	{
		x -= other.x;
		y -= other.y;

		return *this;
	}

	Vector2D& operator*=(float scalar)
	{
		x *= scalar;
		y *= scalar;

		return *this;
	}

	Vector2D& operator/=(float scalar)
	{
		x /= scalar;
		y /= scalar;

		return *this;
	}
};

static_assert(sizeof(Vector2D) == sizeof(float) * 2, "Vector2D must remain tight 8-byte storage.");
static_assert(alignof(Vector2D) == alignof(float), "Vector2D storage must not add default SIMD alignment.");

constexpr Vector2D operator+(const Vector2D& left, const Vector2D& right)
{
	return Vector2D(left.x + right.x, left.y + right.y);
}

constexpr Vector2D operator-(const Vector2D& left, const Vector2D& right)
{
	return Vector2D(left.x - right.x, left.y - right.y);
}

constexpr Vector2D operator-(const Vector2D& vector)
{
	return Vector2D(-vector.x, -vector.y);
}

constexpr Vector2D operator*(const Vector2D& vector, float scalar)
{
	return Vector2D(vector.x * scalar, vector.y * scalar);
}

constexpr Vector2D operator*(float scalar, const Vector2D& vector)
{
	return vector * scalar;
}

constexpr Vector2D operator/(const Vector2D& vector, float scalar)
{
	return Vector2D(vector.x / scalar, vector.y / scalar);
}

constexpr bool operator==(const Vector2D& left, const Vector2D& right)
{
	return left.x == right.x && left.y == right.y;
}

constexpr bool operator!=(const Vector2D& left, const Vector2D& right)
{
	return !(left == right);
}
